package com.dogukantufan00.exercise_tracking_app.data

import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Protokol (sürüm 1) JSON sözleşmesi: docs/ARCHITECTURE.md §15.4 ile birebir uyum. */
class WatchProtocolTest {

    private val snapshotJson = """
        {
          "protocol": 1,
          "workoutId": 42,
          "title": "Push A",
          "startedAt": "2026-11-21T18:30:00.000",
          "appliedEventIds": ["5b0e", "7c1f"],
          "exercises": [
            {
              "workoutExerciseId": 101,
              "name": "Bench Press",
              "target": { "sets": 3, "reps": 10, "weightKg": 40.0 },
              "sets": [ { "id": 900, "setNumber": 1, "weightKg": 40.0, "reps": 10 } ],
              "draft": { "weightKg": 40.0, "reps": 10 },
              "previous": [ { "weightKg": 37.5, "reps": 10 } ]
            }
          ]
        }
    """.trimIndent()

    @Test
    fun snapshotFieldsAreReadCorrectly() {
        val snapshot = ProtocolJson.decodeFromString(WatchSnapshot.serializer(), snapshotJson)

        assertEquals(1, snapshot.protocol)
        assertEquals(42L, snapshot.workoutId)
        assertEquals("Push A", snapshot.title)
        assertEquals("2026-11-21T18:30:00.000", snapshot.startedAt)
        assertEquals(listOf("5b0e", "7c1f"), snapshot.appliedEventIds)

        val exercise = snapshot.exercises.single()
        assertEquals(101L, exercise.workoutExerciseId)
        assertEquals("Bench Press", exercise.name)
        assertEquals(WatchTarget(sets = 3, reps = 10, weightKg = 40.0), exercise.target)
        assertEquals(listOf(WatchSet(id = 900, setNumber = 1, weightKg = 40.0, reps = 10)), exercise.sets)
        assertEquals(WatchSetValue(weightKg = 40.0, reps = 10), exercise.draft)
        assertEquals(listOf(WatchSetValue(weightKg = 37.5, reps = 10)), exercise.previous)
    }

    @Test
    fun nullTargetIsRead() {
        val json = snapshotJson.replace(
            """"target": { "sets": 3, "reps": 10, "weightKg": 40.0 }""",
            """"target": null""",
        )
        val snapshot = ProtocolJson.decodeFromString(WatchSnapshot.serializer(), json)

        assertNull(snapshot.exercises.single().target)
    }

    @Test
    fun unknownFieldsAreIgnored() {
        val json = snapshotJson.replace(""""protocol": 1,""", """"protocol": 1, "futureField": {"a": 1},""")
        val snapshot = ProtocolJson.decodeFromString(WatchSnapshot.serializer(), json)

        assertEquals(42L, snapshot.workoutId)
    }

    @Test
    fun addSetEventHasProtocolFieldNames() {
        val event = AddSetEvent(
            eventId = "uuid-1",
            workoutId = 42,
            createdAt = "2026-11-21T18:41:05.000",
            workoutExerciseId = 101,
            weightKg = 40.0,
            reps = 10,
        )

        val encoded = ProtocolJson.encodeToString(WatchEvent.serializer(), event)
        val obj = Json.parseToJsonElement(encoded).jsonObject

        assertEquals("addSet", obj.getValue("type").toString().trim('"'))
        assertEquals(
            setOf(
                "type", "protocol", "eventId", "workoutId", "workoutExerciseId", "weightKg", "reps", "createdAt",
                "restSeconds",
            ),
            obj.keys,
        )
    }

    @Test
    fun deleteSetEventHasProtocolFieldNames() {
        val event = DeleteSetEvent(
            eventId = "uuid-2",
            workoutId = 42,
            createdAt = "2026-11-21T18:42:00.000",
            setId = 900,
        )

        val encoded = ProtocolJson.encodeToString(WatchEvent.serializer(), event)
        val obj = Json.parseToJsonElement(encoded).jsonObject

        assertEquals("deleteSet", obj.getValue("type").toString().trim('"'))
        assertEquals(
            setOf("type", "protocol", "eventId", "workoutId", "setId", "createdAt"),
            obj.keys,
        )
    }

    @Test
    fun startWorkoutEventHasProtocolFieldNamesWithoutWorkoutId() {
        val event = StartWorkoutEvent(
            eventId = "uuid-3",
            createdAt = "2026-11-22T18:30:00.000",
            programDayId = 11,
        )

        val encoded = ProtocolJson.encodeToString(WatchEvent.serializer(), event)
        val obj = Json.parseToJsonElement(encoded).jsonObject

        assertEquals("startWorkout", obj.getValue("type").toString().trim('"'))
        assertEquals(setOf("type", "protocol", "eventId", "createdAt", "programDayId"), obj.keys)
        assertEquals("11", obj.getValue("programDayId").toString())
    }

    @Test
    fun emptyStartWorkoutEncodesNullProgramDay() {
        val event = StartWorkoutEvent(eventId = "uuid-4", createdAt = "2026-11-22T18:30:00.000", programDayId = null)

        val encoded = ProtocolJson.encodeToString(WatchEvent.serializer(), event)
        val obj = Json.parseToJsonElement(encoded).jsonObject

        assertEquals("null", obj.getValue("programDayId").toString())
    }

    @Test
    fun finishWorkoutEventHasProtocolFieldNames() {
        val event = FinishWorkoutEvent(eventId = "uuid-5", workoutId = 42, createdAt = "2026-11-22T19:30:00.000")

        val encoded = ProtocolJson.encodeToString(WatchEvent.serializer(), event)
        val obj = Json.parseToJsonElement(encoded).jsonObject

        assertEquals("finishWorkout", obj.getValue("type").toString().trim('"'))
        assertEquals(setOf("type", "protocol", "eventId", "createdAt", "workoutId"), obj.keys)
        assertEquals(event, ProtocolJson.decodeFromString(WatchEvent.serializer(), encoded))
    }

    @Test
    fun programIsReadFromPhoneJson() {
        val json = """
            {
              "protocol": 1,
              "programId": 3,
              "name": "PPL",
              "days": [ { "dayId": 11, "name": "Push A", "weekday": 1, "exercises": ["Bench Press"] } ]
            }
        """.trimIndent()

        val program = ProtocolJson.decodeFromString(WatchProgram.serializer(), json)

        assertEquals(3L, program.programId)
        assertEquals(WatchProgramDay(dayId = 11, name = "Push A", weekday = 1, exercises = listOf("Bench Press")), program.days.single())
    }

    @Test
    fun programRoundTrips() {
        val program = WatchProgram(
            programId = 3,
            name = "PPL",
            days = listOf(
                WatchProgramDay(dayId = 11, name = "Push A", weekday = 1, exercises = listOf("Bench Press", "Incline DB Press")),
                WatchProgramDay(dayId = 12, name = "Serbest", weekday = null, exercises = emptyList()),
            ),
        )

        val encoded = ProtocolJson.encodeToString(WatchProgram.serializer(), program)

        assertEquals(program, ProtocolJson.decodeFromString(WatchProgram.serializer(), encoded))
    }

    @Test
    fun appliedRoundTrips() {
        val applied = WatchApplied(appliedEventIds = listOf("a", "b"))

        val encoded = ProtocolJson.encodeToString(WatchApplied.serializer(), applied)

        assertEquals(applied, ProtocolJson.decodeFromString(WatchApplied.serializer(), encoded))
    }

    @Test
    fun eventListRoundTrips() {
        val serializer = ListSerializer(WatchEvent.serializer())
        val events: List<WatchEvent> = listOf(
            AddSetEvent(
                eventId = "a",
                workoutId = 42,
                createdAt = "2026-11-21T18:41:05.000",
                workoutExerciseId = 101,
                weightKg = 42.5,
                reps = 8,
            ),
            DeleteSetEvent(eventId = "b", workoutId = 42, createdAt = "2026-11-21T18:42:00.000", setId = 900),
        )

        val encoded = ProtocolJson.encodeToString(serializer, events)
        val decoded = ProtocolJson.decodeFromString(serializer, encoded)

        assertEquals(events, decoded)
        assertTrue(decoded[0] is AddSetEvent)
        assertTrue(decoded[1] is DeleteSetEvent)
    }

    @Test
    fun snapshotWithoutRest_readsNull() {
        val snapshot = ProtocolJson.decodeFromString(WatchSnapshot.serializer(), snapshotJson)

        assertNull(snapshot.rest)
    }

    @Test
    fun snapshotWithRest_readsRest() {
        val json = snapshotJson.replace(
            "\"appliedEventIds\": [\"5b0e\", \"7c1f\"],",
            "\"appliedEventIds\": [\"5b0e\", \"7c1f\"],\n" +
                "  \"rest\": { \"restId\": \"r1\", \"endsAt\": \"2026-11-24T18:42:30.000\", \"totalSeconds\": 90 },",
        )

        val snapshot = ProtocolJson.decodeFromString(WatchSnapshot.serializer(), json)

        assertEquals(WatchRest("r1", "2026-11-24T18:42:30.000", 90), snapshot.rest)
    }

    @Test
    fun restEvents_readDartJson() {
        val adjust = ProtocolJson.decodeFromString(
            WatchEvent.serializer(),
            """{"protocol":1,"eventId":"e1","type":"adjustRest","workoutId":42,"restId":"r1","deltaSeconds":-15,"createdAt":"2026-11-24T18:41:00.000"}""",
        )
        val skip = ProtocolJson.decodeFromString(
            WatchEvent.serializer(),
            """{"protocol":1,"eventId":"e2","type":"skipRest","workoutId":42,"restId":"r1","createdAt":"2026-11-24T18:41:10.000"}""",
        )
        val seconds = ProtocolJson.decodeFromString(
            WatchEvent.serializer(),
            """{"protocol":1,"eventId":"e3","type":"setRestSeconds","seconds":120,"createdAt":"2026-11-24T18:41:20.000"}""",
        )

        assertEquals(
            AdjustRestEvent(eventId = "e1", workoutId = 42, createdAt = "2026-11-24T18:41:00.000", restId = "r1", deltaSeconds = -15),
            adjust,
        )
        assertEquals(SkipRestEvent(eventId = "e2", workoutId = 42, createdAt = "2026-11-24T18:41:10.000", restId = "r1"), skip)
        assertEquals(SetRestSecondsEvent(eventId = "e3", createdAt = "2026-11-24T18:41:20.000", seconds = 120), seconds)
    }

    @Test
    fun addSetRestSeconds_roundTripsAndDefaultsToNull() {
        val event = AddSetEvent(
            eventId = "a",
            workoutId = 42,
            createdAt = "2026-11-24T18:41:05.000",
            workoutExerciseId = 101,
            weightKg = 42.5,
            reps = 8,
            restSeconds = 120,
        )

        val encoded = ProtocolJson.encodeToString(WatchEvent.serializer(), event)

        assertTrue(encoded.contains("\"restSeconds\":120"))
        assertEquals(event, ProtocolJson.decodeFromString(WatchEvent.serializer(), encoded))
        val old = ProtocolJson.decodeFromString(
            WatchEvent.serializer(),
            """{"protocol":1,"eventId":"b","type":"addSet","workoutId":42,"workoutExerciseId":101,"weightKg":40.0,"reps":10,"createdAt":"2026-11-24T18:41:05.000"}""",
        ) as AddSetEvent
        assertNull(old.restSeconds)
    }
}
