package dev.digitalducktape.openride.ui.designsystem

import androidx.compose.ui.tooling.preview.Preview

/**
 * Previews a composable in the bike's app window: 1920 × 1008 px at 240 dpi, i.e. 1280 × 672 dp
 * (see [BikeWindow]), on the app background.
 */
@Preview(
    name = "Bike window",
    device = "spec:width=1920px,height=1008px,dpi=240",
    showBackground = true,
    backgroundColor = 0xFF0F1216,
)
annotation class BikePreview

/** Previews a single component on the app background, sized to its content. */
@Preview(name = "Component", showBackground = true, backgroundColor = 0xFF0F1216)
annotation class ComponentPreview
