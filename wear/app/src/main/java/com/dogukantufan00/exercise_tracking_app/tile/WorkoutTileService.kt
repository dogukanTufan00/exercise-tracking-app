package com.dogukantufan00.exercise_tracking_app.tile

import androidx.concurrent.futures.CallbackToFutureAdapter
import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders
import androidx.wear.protolayout.DimensionBuilders
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.dogukantufan00.exercise_tracking_app.LaunchActions
import com.dogukantufan00.exercise_tracking_app.MainActivity
import com.dogukantufan00.exercise_tracking_app.WatchApp
import com.dogukantufan00.exercise_tracking_app.domain.formatExerciseCount
import com.google.common.util.concurrent.ListenableFuture
import java.time.LocalDate

/**
 * Saat Tile'ı (bkz. docs/ARCHITECTURE.md §15.8 madde 4). Durum ve metinler [tileStateOf]'tan gelir; bu sınıf
 * yalnızca protolayout düzenini kurar. Veri değişince [TileUpdater] yeniden çizilmesini ister.
 */
class WorkoutTileService : TileService() {

    override fun onTileRequest(requestParams: RequestBuilders.TileRequest): ListenableFuture<TileBuilders.Tile> =
        CallbackToFutureAdapter.getFuture { completer ->
            val app = application as WatchApp
            val state = tileStateOf(
                workout = app.syncRepository.workout.value,
                program = app.syncRepository.program.value,
                today = LocalDate.now().dayOfWeek,
            )
            val palette = tilePaletteOf(app.themeSource.themeId.value)
            val root = buildLayout(state, palette)
            val timeline = TimelineBuilders.Timeline.Builder()
                .addTimelineEntry(
                    TimelineBuilders.TimelineEntry.Builder()
                        .setLayout(LayoutElementBuilders.Layout.Builder().setRoot(root).build())
                        .build(),
                )
                .build()
            val tile = TileBuilders.Tile.Builder()
                .setResourcesVersion(RESOURCES_VERSION)
                .setTileTimeline(timeline)
                // Gece yarısı günü değiştirir; veri olmasa da en geç bu sürede yeniden çizilir.
                .setFreshnessIntervalMillis(FRESHNESS_MILLIS)
                .build()
            completer.set(tile)
            "WorkoutTile"
        }

    override fun onTileResourcesRequest(
        requestParams: RequestBuilders.ResourcesRequest,
    ): ListenableFuture<androidx.wear.protolayout.ResourceBuilders.Resources> =
        CallbackToFutureAdapter.getFuture { completer ->
            // Tile yalnızca renk ve metin kullanır; görsel kaynağı yok.
            completer.set(
                androidx.wear.protolayout.ResourceBuilders.Resources.Builder()
                    .setVersion(RESOURCES_VERSION)
                    .build(),
            )
            "WorkoutTileResources"
        }

    private fun buildLayout(state: WorkoutTileState, palette: TilePalette): LayoutElementBuilders.LayoutElement {
        val (title, subtitle, buttonLabel, action) = when (state) {
            is WorkoutTileState.Active -> Content(
                title = state.title,
                subtitle = "${state.setCount} set",
                buttonLabel = "Devam et",
                action = openApp(),
            )
            is WorkoutTileState.Today -> Content(
                title = "Bugün: ${state.dayName}",
                subtitle = formatExerciseCount(state.exerciseCount),
                buttonLabel = "Başla",
                action = openApp(
                    LaunchActions.EXTRA_START_DAY_ID to
                        ActionBuilders.AndroidLongExtra.Builder().setValue(state.dayId).build(),
                ),
            )
            is WorkoutTileState.StartNew -> if (state.hasProgram) {
                Content(
                    title = "Bugün planlı gün yok",
                    subtitle = "Program seç",
                    buttonLabel = "Antrenman başlat",
                    action = openApp(LaunchActions.EXTRA_OPEN_START to booleanExtra()),
                )
            } else {
                Content(
                    title = "Program yok",
                    subtitle = "Boş antrenman",
                    buttonLabel = "Antrenman başlat",
                    action = openApp(LaunchActions.EXTRA_START_EMPTY to booleanExtra()),
                )
            }
        }

        val column = LayoutElementBuilders.Column.Builder()
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .addContent(
                LayoutElementBuilders.Text.Builder()
                    .setText(title)
                    .setMaxLines(1)
                    .setFontStyle(
                        LayoutElementBuilders.FontStyle.Builder()
                            .setSize(DimensionBuilders.sp(16f))
                            .setWeight(LayoutElementBuilders.FONT_WEIGHT_BOLD)
                            .setColor(ColorBuilders.argb(palette.onSurface))
                            .build(),
                    )
                    .build(),
            )
            .addContent(
                LayoutElementBuilders.Text.Builder()
                    .setText(subtitle)
                    .setMaxLines(1)
                    .setFontStyle(
                        LayoutElementBuilders.FontStyle.Builder()
                            .setSize(DimensionBuilders.sp(12f))
                            .setColor(ColorBuilders.argb(palette.muted))
                            .build(),
                    )
                    .build(),
            )
            .addContent(
                LayoutElementBuilders.Spacer.Builder()
                    .setHeight(DimensionBuilders.dp(8f))
                    .build(),
            )
            .addContent(buttonBox(buttonLabel, action, palette))
            .build()

        return LayoutElementBuilders.Box.Builder()
            .setWidth(DimensionBuilders.expand())
            .setHeight(DimensionBuilders.expand())
            .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
            .setVerticalAlignment(LayoutElementBuilders.VERTICAL_ALIGN_CENTER)
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setBackground(
                        ModifiersBuilders.Background.Builder()
                            .setColor(ColorBuilders.argb(palette.background))
                            .build(),
                    )
                    .setPadding(
                        ModifiersBuilders.Padding.Builder()
                            .setAll(DimensionBuilders.dp(10f))
                            .build(),
                    )
                    .build(),
            )
            .addContent(column)
            .build()
    }

    private fun buttonBox(
        label: String,
        action: ActionBuilders.Action,
        palette: TilePalette,
    ): LayoutElementBuilders.LayoutElement =
        LayoutElementBuilders.Box.Builder()
            .setModifiers(
                ModifiersBuilders.Modifiers.Builder()
                    .setClickable(
                        ModifiersBuilders.Clickable.Builder()
                            .setId("tile_action")
                            .setOnClick(action)
                            .build(),
                    )
                    .setBackground(
                        ModifiersBuilders.Background.Builder()
                            .setColor(ColorBuilders.argb(palette.primary))
                            .setCorner(
                                ModifiersBuilders.Corner.Builder()
                                    .setRadius(DimensionBuilders.dp(22f))
                                    .build(),
                            )
                            .build(),
                    )
                    .setPadding(
                        ModifiersBuilders.Padding.Builder()
                            .setStart(DimensionBuilders.dp(16f))
                            .setEnd(DimensionBuilders.dp(16f))
                            .setTop(DimensionBuilders.dp(8f))
                            .setBottom(DimensionBuilders.dp(8f))
                            .build(),
                    )
                    .build(),
            )
            .addContent(
                LayoutElementBuilders.Text.Builder()
                    .setText(label)
                    .setMaxLines(1)
                    .setFontStyle(
                        LayoutElementBuilders.FontStyle.Builder()
                            .setSize(DimensionBuilders.sp(14f))
                            .setWeight(LayoutElementBuilders.FONT_WEIGHT_BOLD)
                            .setColor(ColorBuilders.argb(palette.onPrimary))
                            .build(),
                    )
                    .build(),
            )
            .build()

    /** Uygulamayı açan eylem; [extras] MainActivity'ye Intent ekstraları olarak gider. */
    private fun openApp(vararg extras: Pair<String, ActionBuilders.AndroidExtra>): ActionBuilders.Action {
        val activity = ActionBuilders.AndroidActivity.Builder()
            .setPackageName(packageName)
            .setClassName(MainActivity::class.java.name)
        extras.forEach { (key, value) -> activity.addKeyToExtraMapping(key, value) }
        return ActionBuilders.LaunchAction.Builder()
            .setAndroidActivity(activity.build())
            .build()
    }

    private fun booleanExtra(): ActionBuilders.AndroidExtra =
        ActionBuilders.AndroidBooleanExtra.Builder().setValue(true).build()

    /** Düzen için çözülmüş metinler ve eylem. */
    private data class Content(
        val title: String,
        val subtitle: String,
        val buttonLabel: String,
        val action: ActionBuilders.Action,
    )

    companion object {
        private const val RESOURCES_VERSION = "1"
        private const val FRESHNESS_MILLIS = 15 * 60 * 1000L
    }
}
