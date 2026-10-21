package dev.digitalducktape.openride.ui.main

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
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
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.component.OrNavRail
import dev.digitalducktape.openride.ui.designsystem.component.OrNavRailItem
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
 * The tabbed section of the app: the left [OrNavRail] (Home / Classes / Games / History /
 * Profile, see [TopLevelDestination]; a rail rather than a bottom bar so every tab keeps the
 * window's full 672 dp of height, docs/MAIN_UI_REFRESH.md §3) plus a nested `NavHost` for those
 * destinations. Starting a ride or switching riders navigates the
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

    // Same options whether a tab comes from the rail or an in-screen shortcut (the
    // home header's avatar chip): single top, state saved/restored per tab.
    fun navigateToTab(route: String) {
        innerNavController.navigate(route) {
            popUpTo(innerNavController.graph.findStartDestination().id) {
                saveState = true
            }
            launchSingleTop = true
            restoreState = true
        }
    }

    Row(modifier = modifier.fillMaxSize().background(OrColors.Background)) {
        OrNavRail {
            TopLevelDestination.entries.forEach { destination ->
                OrNavRailItem(
                    label = destination.label,
                    icon = destination.icon,
                    emoji = destination.emoji,
                    selected = currentRoute == destination.route,
                    onClick = { navigateToTab(destination.route) },
                )
            }
        }
        NavHost(
            navController = innerNavController,
            startDestination = TopLevelDestination.Start.route,
            modifier = Modifier.weight(1f).fillMaxHeight(),
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
                val availableUpdate by appContainer.updateAvailability.collectAsState()
                val bannerDismissed by appContainer.updateBannerDismissed.collectAsState()
                HomeRoute(
                    viewModel = viewModel,
                    onQuickStart = { outerNavController.navigate(Destinations.InRide) },
                    onOpenProfile = { navigateToTab(MainTabs.Profile) },
                    onOpenGames = { launchGames(context) },
                    updateVersionName = availableUpdate?.versionName?.takeUnless { bannerDismissed },
                    onOpenUpdate = { outerNavController.navigate(Destinations.AppUpdate) },
                    onDismissUpdate = { appContainer.dismissUpdateBanner() },
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
    }
}
