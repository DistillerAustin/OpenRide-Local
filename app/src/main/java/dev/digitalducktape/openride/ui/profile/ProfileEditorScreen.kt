package dev.digitalducktape.openride.ui.profile

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import dev.digitalducktape.openride.core.files.OpenRideFileProvider
import dev.digitalducktape.openride.core.profile.AvatarPhotoStore
import dev.digitalducktape.openride.ui.common.ProfileAvatar
import dev.digitalducktape.openride.ui.designsystem.BikePreview
import dev.digitalducktape.openride.ui.designsystem.LocalOrAccent
import dev.digitalducktape.openride.ui.designsystem.OrColors
import dev.digitalducktape.openride.ui.designsystem.OrSpacing
import dev.digitalducktape.openride.ui.designsystem.OrType
import dev.digitalducktape.openride.ui.designsystem.component.OrEyebrow
import dev.digitalducktape.openride.ui.designsystem.component.OrPrimaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSecondaryButton
import dev.digitalducktape.openride.ui.designsystem.component.OrSwatch
import dev.digitalducktape.openride.ui.designsystem.component.OrTextField
import dev.digitalducktape.openride.ui.designsystem.component.OrTile
import dev.digitalducktape.openride.ui.designsystem.component.OrTopBar
import dev.digitalducktape.openride.ui.designsystem.riderAccent
import dev.digitalducktape.openride.ui.theme.OpenRideTheme
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * The profile form connected to its [ProfileEditorViewModel] (the Route half of the Route/Screen
 * split), shared by "Add rider" and "Edit profile" via the view model's two modes. It owns what
 * the stateless [ProfileEditorScreen] can't: the camera and its permission, and saving.
 *
 * The avatar photo comes from the tablet's built-in camera (TakePicture into a FileProvider'd
 * cache file), which [AvatarPhotoStore.importCapture] then center-crops for the circular avatar.
 * The app declares CAMERA for the mini-games head tracker, and Android refuses
 * ACTION_IMAGE_CAPTURE from an app that declares CAMERA without holding it, so the photo button
 * asks for the permission first when needed.
 */
@Composable
fun ProfileEditorRoute(
    viewModel: ProfileEditorViewModel,
    avatarPhotoStore: AvatarPhotoStore,
    title: String,
    onSaved: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var cameraError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(Unit) { viewModel.loadForEdit() }
    LaunchedEffect(uiState.saved) {
        if (uiState.saved) onSaved()
    }

    // One capture target per screen visit; the camera app writes the raw photo here and
    // importCapture deletes it once the cropped avatar is stored.
    val captureFile = remember {
        File(context.cacheDir, "avatar_capture/capture_${System.currentTimeMillis()}.jpg")
            .also { it.parentFile?.mkdirs() }
    }
    val takePicture = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { success ->
        if (!success) return@rememberLauncherForActivityResult
        scope.launch {
            val storedPath = withContext(Dispatchers.IO) { avatarPhotoStore.importCapture(captureFile) }
            if (storedPath != null) {
                cameraError = null
                viewModel.onPhotoCaptured(storedPath)
            } else {
                cameraError = "Couldn't read the photo from the camera"
            }
        }
    }

    fun launchCamera() {
        try {
            takePicture.launch(OpenRideFileProvider.uriFor(context, captureFile))
        } catch (_: ActivityNotFoundException) {
            cameraError = "No camera app available on this tablet"
        } catch (_: SecurityException) {
            cameraError = "OpenRide needs camera access to take a photo"
        }
    }
    val requestCameraPermission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        if (granted) launchCamera() else cameraError = "OpenRide needs camera access to take a photo"
    }

    ProfileEditorScreen(
        uiState = uiState,
        title = title,
        cameraError = cameraError,
        onNameChange = viewModel::onNameChange,
        onWeightChange = viewModel::onWeightChange,
        onFtpChange = viewModel::onFtpChange,
        onTakePhoto = {
            val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) ==
                PackageManager.PERMISSION_GRANTED
            if (granted) launchCamera() else requestCameraPermission.launch(Manifest.permission.CAMERA)
        },
        onRemovePhoto = viewModel::onPhotoRemoved,
        onColorSelected = viewModel::onAvatarColorChange,
        onEmojiSelected = viewModel::onAvatarEmojiChange,
        onSave = { scope.launch { viewModel.save() } },
        onCancel = onCancel,
        modifier = modifier,
    )
}

/**
 * The profile form (PRD P0-3), stateless: one page that never scrolls, for the bike's 1280 × 672
 * dp window. The avatar (photo, colour, icon) in a tile on the left, name, weight and FTP in a
 * tile on the right.
 *
 * Save and Cancel live in the top bar, not under the fields: the tablet's on-screen keyboard
 * covers the lower half of the screen, so actions below the inputs would be hidden while typing.
 *
 * The page previews the rider's own colour: the accent (Save, the focused field) follows the
 * avatar colour being picked, as it will across the app once this rider is active.
 */
@Composable
fun ProfileEditorScreen(
    uiState: ProfileEditorUiState,
    title: String,
    cameraError: String?,
    onNameChange: (String) -> Unit,
    onWeightChange: (String) -> Unit,
    onFtpChange: (String) -> Unit,
    onTakePhoto: () -> Unit,
    onRemovePhoto: () -> Unit,
    onColorSelected: (Int) -> Unit,
    onEmojiSelected: (String) -> Unit,
    onSave: () -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    CompositionLocalProvider(LocalOrAccent provides riderAccent(uiState.avatarColor)) {
        Column(modifier = modifier.fillMaxSize().background(OrColors.Background)) {
            OrTopBar(
                title = title,
                actions = {
                    OrSecondaryButton(text = "Cancel", onClick = onCancel)
                    OrPrimaryButton(text = "Save", onClick = onSave)
                },
            )
            Row(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(start = OrSpacing.ScreenGutter, end = OrSpacing.ScreenGutter, top = OrSpacing.sm, bottom = OrSpacing.lg),
                horizontalArrangement = Arrangement.spacedBy(OrSpacing.lg),
            ) {
                AvatarTile(
                    uiState = uiState,
                    cameraError = cameraError,
                    onTakePhoto = onTakePhoto,
                    onRemovePhoto = onRemovePhoto,
                    onColorSelected = onColorSelected,
                    onEmojiSelected = onEmojiSelected,
                    modifier = Modifier.weight(1f).fillMaxHeight(),
                )
                OrTile(modifier = Modifier.weight(1f).fillMaxHeight()) {
                    OrEyebrow(text = "Rider", modifier = Modifier.padding(bottom = OrSpacing.md))
                    OrTextField(
                        value = uiState.name,
                        onValueChange = onNameChange,
                        label = "Name",
                        error = uiState.nameError,
                        keyboardOptions = KeyboardOptions(imeAction = ImeAction.Next),
                        modifier = Modifier.fillMaxWidth(),
                    )
                    OrTextField(
                        value = uiState.weightLbsInput,
                        onValueChange = onWeightChange,
                        label = "Weight (lbs) — optional",
                        error = uiState.weightError,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal, imeAction = ImeAction.Next),
                        modifier = Modifier.fillMaxWidth().padding(top = OrSpacing.sm),
                    )
                    OrTextField(
                        value = uiState.ftpInput,
                        onValueChange = onFtpChange,
                        label = "FTP (watts) — optional",
                        error = uiState.ftpError,
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done),
                        modifier = Modifier.fillMaxWidth().padding(top = OrSpacing.sm),
                    )
                    Text(
                        text = "Weight sharpens calorie estimates; FTP sets your power zones.",
                        style = OrType.Caption,
                        color = OrColors.OnSurfaceMuted,
                        modifier = Modifier.padding(top = OrSpacing.sm),
                    )
                }
            }
        }
    }
}

@Composable
private fun AvatarTile(
    uiState: ProfileEditorUiState,
    cameraError: String?,
    onTakePhoto: () -> Unit,
    onRemovePhoto: () -> Unit,
    onColorSelected: (Int) -> Unit,
    onEmojiSelected: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    OrTile(modifier = modifier) {
        OrEyebrow(text = "Avatar")
        Row(
            modifier = Modifier.padding(top = OrSpacing.md),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.lg),
        ) {
            ProfileAvatar(
                photoPath = uiState.avatarPhotoPath,
                color = Color(uiState.avatarColor),
                emoji = uiState.avatarEmoji,
                size = 120.dp,
                emojiSize = 48.sp,
            )
            Column(verticalArrangement = Arrangement.spacedBy(OrSpacing.sm)) {
                OrSecondaryButton(
                    text = ProfileEditorLabels.photoAction(hasPhoto = uiState.avatarPhotoPath != null),
                    onClick = onTakePhoto,
                )
                if (uiState.avatarPhotoPath != null) {
                    OrSecondaryButton(text = "Remove photo", onClick = onRemovePhoto)
                }
            }
        }
        // Always reserves its line, so an error appearing doesn't push the pickers down.
        Text(
            text = cameraError ?: "",
            style = OrType.Caption,
            color = OrColors.Warning,
            modifier = Modifier.padding(top = OrSpacing.sm),
        )

        OrEyebrow(text = "Colour", modifier = Modifier.padding(top = OrSpacing.md))
        Row(
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.sm + OrSpacing.xs),
            modifier = Modifier.padding(top = OrSpacing.sm),
        ) {
            AvatarOptions.colors.forEachIndexed { index, colorInt ->
                OrSwatch(
                    selected = uiState.avatarColor == colorInt,
                    color = Color(colorInt),
                    onClick = { onColorSelected(colorInt) },
                    contentDescription = ProfileEditorLabels.colorDescription(index, AvatarOptions.colors.size),
                )
            }
        }

        OrEyebrow(text = "Icon", modifier = Modifier.padding(top = OrSpacing.lg))
        Row(
            horizontalArrangement = Arrangement.spacedBy(OrSpacing.sm + OrSpacing.xs),
            modifier = Modifier.padding(top = OrSpacing.sm),
        ) {
            AvatarOptions.emojis.forEach { emoji ->
                OrSwatch(
                    selected = uiState.avatarEmoji == emoji,
                    color = OrColors.SurfaceRaised,
                    onClick = { onEmojiSelected(emoji) },
                    contentDescription = ProfileEditorLabels.emojiDescription(emoji),
                ) {
                    Text(text = emoji, fontSize = 22.sp)
                }
            }
        }
    }
}

@BikePreview
@Composable
private fun ProfileEditorScreenPreview() {
    OpenRideTheme {
        ProfileEditorScreen(
            uiState = ProfileEditorUiState(
                name = "Sam",
                avatarColor = AvatarOptions.colors[1],
                weightLbsInput = "185",
                ftpInput = "0",
                ftpError = "Enter an FTP in watts greater than 0",
            ),
            title = "Edit profile",
            cameraError = null,
            onNameChange = {},
            onWeightChange = {},
            onFtpChange = {},
            onTakePhoto = {},
            onRemovePhoto = {},
            onColorSelected = {},
            onEmojiSelected = {},
            onSave = {},
            onCancel = {},
        )
    }
}
