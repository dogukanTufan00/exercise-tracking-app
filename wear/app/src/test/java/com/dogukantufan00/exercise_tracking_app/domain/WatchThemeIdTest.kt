package com.dogukantufan00.exercise_tracking_app.domain

import org.junit.Assert.assertEquals
import org.junit.Test

class WatchThemeIdTest {

    @Test
    fun watchThemeIdOf_mapsEachPhoneThemeName() {
        assertEquals(WatchThemeId.DarkOrange, watchThemeIdOf("darkOrange"))
        assertEquals(WatchThemeId.RedBlack, watchThemeIdOf("redBlack"))
        assertEquals(WatchThemeId.YellowNavy, watchThemeIdOf("yellowNavy"))
        assertEquals(WatchThemeId.LightBlue, watchThemeIdOf("lightBlue"))
    }

    @Test
    fun watchThemeIdOf_nullFallsBackToDarkOrange() {
        assertEquals(WatchThemeId.DarkOrange, watchThemeIdOf(null))
    }

    @Test
    fun watchThemeIdOf_unknownNameFallsBackToDarkOrange() {
        assertEquals(WatchThemeId.DarkOrange, watchThemeIdOf("neonPink"))
        assertEquals(WatchThemeId.DarkOrange, watchThemeIdOf("LightBlue"))
    }
}
