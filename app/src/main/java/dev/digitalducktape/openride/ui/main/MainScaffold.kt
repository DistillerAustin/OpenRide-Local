package dev.digitalducktape.openride.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import dev.digitalducktape.openride.AppContainer
import dev.digitalducktape.openride.viewModelFactory
import dev.digitalducktape.openride.ui.classes.ClassesScreen
import dev.digitalducktape.openride.core.sensor.offlineFor
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.component.LocalTopBarActions
import dev.digitalducktape.openride.ui.designsystem.component.OrNavBar
import dev.digitalducktape.openride.ui.designsystem.component.OrNavBarItem
import dev.digitalducktape.openride.ui.designsystem.component.OrTopBar
import dev.digitalducktape.openride.ui.designsystem.component.TopBarActionsHolder
import kotlinx.coroutines.flow.combine
import dev.digitalducktape.openride.ui.classes.ClassesViewModel
import dev.digitalducktape.openride.ui.games.GamesLauncherScreen
import dev.digitalducktape.openride.ui.games.launchGames
import dev.digitalducktape.openride.ui.history.HistoryScreen
import dev.digitalducktape.openride.ui.history.HistoryViewModel
import dev.digitalducktape.openride.ui.home.HomeRoute
import dev.digitalducktape.openride.ui.home.HomeViewModel
import dev.digitalducktape.openride.ui.navigation.Destinations
import dev.digitalducktape.openride.ui.navigation.MainTabs
import dev.digitalducktape.openride.ui.profile.ProfileTabScreen
import dev.digitalducktape.openride.ui.profile.ProfileTabViewModel

/**
 * The tabbed section of the app (docs/MAIN_UI_REFRESH.md §3, "Shell"): the shared [OrTopBar]
 * (the tab's title, the screen's own actions, the rider), a nested `NavHost` for the tabs, and
 * the [OrNavBar] along the bottom (Home / Classes / Games / History / Profile, see
 * [TopLevelDestination]), as on the stock bike software. Starting a ride or switching riders navigates the
 * *outer* nav controller (passed in), which lives one level up in
 * [dev.digitalducktape.openride.ui.navigation.OpenRideNavHost] — those flows intentionally
 * leave this tabbed chrome behind rather than becoming a fifth tab.
 */
@Composable
fun MainScaffold(
    appContainer: AppContainer,
    outerNavController: NavHostController,
    modifier: Modifier = Modifier,
) {
    val innerNavController = rememberNavController()
    val backStackEntry by innerNavController.currentBackStackEntryAsState()
    val currentRoute = backStackEntry?.destination?.route

    // Same options whether a tab comes from the bar or a shortcut (the top bar's rider chip):
    // single top, state saved/restored per tab.
    fun navigateToTab(route: String) {
        innerNavController.navigate(route) {
            popUpTo(innerNavController.graph.findStartDestination().id) {
                saveState = true
            }
            launchSingleTop = true
            restoreState = true
        }
    }

    val activeProfile by remember {
        combine(
            appContainer.activeProfileHolder.activeProfileId,
            appContainer.profileRepository.observeProfiles(),
        ) { id, profiles -> profiles.firstOrNull { it.id == id } }
    }.collectAsState(initial = null)
    val sensorsOffline by remember { appContainer.bikeDataSource.connectionState.offlineFor() }
        .collectAsState(initial = false)
    val heartRateState by appContainer.heartRateManager.connectionState.collectAsState()
    val heartRateBpm by appContainer.heartRateManager.bpm.collectAsState()
    val availableUpdate by appContainer.updateAvailability.collectAsState()
    val updateBannerDismissed by appContainer.updateBannerDismissed.collectAsState()
    val topBarActions = remember { TopBarActionsHolder() }
    val currentTab = TopLevelDestination.entries.firstOrNull { it.route == currentRoute } ?: TopLevelDestination.Start

    CompositionLocalProvider(LocalTopBarActions provides topBarActions) {
        Column(modifier = modifier.fillMaxSize().background(OrColors.Background)) {
            OrTopBar(
                title = currentTab.label,
                actions = { topBarActions.content?.invoke(this) },
                trailing = { RiderChip(profile = activeProfile, onClick = { navigateToTab(MainTabs.Profile) }) },
            )
            NavHost(
                navController = innerNavController,
                startDestination = TopLevelDestination.Start.route,
                modifier = Modifier.weight(1f).fillMaxWidth(),
            ) {
                composable(MainTabs.Home) {
                    val context = LocalContext.current
                    val viewModel: HomeViewModel = viewModel(
                        factory = viewModelFactory {
                            HomeViewModel(
                                appContainer.activeProfileHolder,
                                appContainer.profileRepository,
                                appContainer.rideSessionManager,
                            )
                        },
                    )
                    HomeRoute(
                        viewModel = viewModel,
                        onQuickStart = { outerNavController.navigate(Destinations.InRide) },
                        onOpenGames = { launchGames(context) },
                    )
                }
                composable(MainTabs.Classes) {
                    val viewModel: ClassesViewModel = viewModel(
                        factory = viewModelFactory {
                            ClassesViewModel(
                                appContainer.contentRepository,
                                appContainer.rideSessionManager,
                                appContainer.activeProfileHolder,
                                appContainer.rideRepository,
                            )
                        },
                    )
                    ClassesScreen(
                        viewModel = viewModel,
                        onStartVideoRide = { videoId ->
                            outerNavController.navigate(Destinations.videoRide(videoId))
                        },
                        onOpenCreator = { sourceId ->
                            outerNavController.navigate(Destinations.creator(sourceId))
                        },
                    )
                }
                composable(MainTabs.Games) {
                    // A launcher: the Games hub inside Godot holds the picker, circuits and settings.
                    val context = LocalContext.current
                    val saving by appContainer.gameVisitManager.saving.collectAsState()
                    GamesLauncherScreen(saving = saving, onEnter = { launchGames(context) })
                }
                composable(MainTabs.History) {
                    val viewModel: HistoryViewModel = viewModel(
                        factory = viewModelFactory {
                            HistoryViewModel(appContainer.activeProfileHolder, appContainer.rideRepository)
                        },
                    )
                    HistoryScreen(
                        viewModel = viewModel,
                        onRideSelected = { rideId ->
                            outerNavController.navigate(Destinations.rideSummary(rideId))
                        },
                    )
                }
                composable(MainTabs.Profile) {
                    val viewModel: ProfileTabViewModel = viewModel(
                        factory = viewModelFactory {
                            ProfileTabViewModel(
                                appContainer.activeProfileHolder,
                                appContainer.profileRepository,
                                appContainer.backupRepository,
                            )
                        },
                    )
                    ProfileTabScreen(
                        viewModel = viewModel,
                        onEditProfile = { outerNavController.navigate(Destinations.ProfileEdit) },
                        onSwitchRider = {
                            outerNavController.navigate(Destinations.ProfileSelect) {
                                popUpTo(Destinations.Main) { inclusive = true }
                            }
                        },
                        onRestoreComplete = {
                            // The active profile (and possibly its id entirely) may no longer be
                            // meaningful after a restore, so route back to profile select the same
                            // way "Switch rider" does rather than staying on a now-stale screen.
                            outerNavController.navigate(Destinations.ProfileSelect) {
                                popUpTo(Destinations.Main) { inclusive = true }
                            }
                        },
                        onManageHeartRateStrap = {
                            // Lives in the outer nav graph (see OpenRideNavHost), same reasoning as
                            // "switch rider": pairing is a full-screen flow, not a fifth tab.
                            outerNavController.navigate(Destinations.HrPairing)
                        },
                        onManageAppUpdates = { outerNavController.navigate(Destinations.AppUpdate) },
                        onManageContentSources = {
                            outerNavController.navigate(Destinations.ContentSources)
                        },
                        routeHolder = appContainer.routeHolder,
                    )
                }
            }
            OrNavBar {
                TopLevelDestination.entries.forEach { destination ->
                    OrNavBarItem(
                        label = destination.label,
                        icon = destination.icon,
                        emoji = destination.emoji,
                        selected = currentRoute == destination.route,
                        onClick = { navigateToTab(destination.route) },
                    )
                }
            }
        }
    }
}
