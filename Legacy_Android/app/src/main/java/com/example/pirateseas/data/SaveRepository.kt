package com.example.pirateseas.data

import android.content.Context
import android.content.SharedPreferences
import com.example.pirateseas.model.CaughtFish
import com.example.pirateseas.model.CrewMember
import com.example.pirateseas.model.CrewRole
import com.example.pirateseas.model.FishRarity
import com.example.pirateseas.model.ShipType
import com.example.pirateseas.model.ShipUpgrades
import org.json.JSONArray
import org.json.JSONObject

data class PlayerSaveData(
    val level: Int = 1,
    val xp: Int = 0,
    val gold: Int = 200,
    val wood: Int = 30,
    val iron: Int = 10,
    val currentShip: ShipType = ShipType.ROWBOAT,
    val upgrades: ShipUpgrades = ShipUpgrades(),
    val crew: List<CrewMember> = emptyList(),
    val cargoFish: List<CaughtFish> = emptyList()
)

class SaveRepository(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences("pirate_seas_save", Context.MODE_PRIVATE)

    fun save(data: PlayerSaveData) {
        val editor = prefs.edit()
        editor.putInt("level", data.level)
        editor.putInt("xp", data.xp)
        editor.putInt("gold", data.gold)
        editor.putInt("wood", data.wood)
        editor.putInt("iron", data.iron)
        editor.putString("currentShip", data.currentShip.name)

        // Upgrades
        val upgJson = JSONObject().apply {
            put("hull", data.upgrades.hullLevel)
            put("sails", data.upgrades.sailsLevel)
            put("cannons", data.upgrades.cannonsLevel)
            put("cargo", data.upgrades.cargoLevel)
        }
        editor.putString("upgrades", upgJson.toString())

        // Crew
        val crewArray = JSONArray()
        data.crew.forEach { member ->
            val obj = JSONObject()
            obj.put("role", member.role.name)
            obj.put("level", member.level)
            crewArray.put(obj)
        }
        editor.putString("crew", crewArray.toString())

        // Fish
        val fishArray = JSONArray()
        data.cargoFish.forEach { fish ->
            val obj = JSONObject()
            obj.put("id", fish.id)
            obj.put("name", fish.name)
            obj.put("rarity", fish.rarity.name)
            obj.put("weight", fish.weightKg.toDouble())
            obj.put("value", fish.value)
            fishArray.put(obj)
        }
        editor.putString("fish", fishArray.toString())

        editor.apply()
    }

    fun load(): PlayerSaveData {
        if (!prefs.contains("level")) {
            return PlayerSaveData()
        }

        val level = prefs.getInt("level", 1)
        val xp = prefs.getInt("xp", 0)
        val gold = prefs.getInt("gold", 200)
        val wood = prefs.getInt("wood", 30)
        val iron = prefs.getInt("iron", 10)
        val shipStr = prefs.getString("currentShip", ShipType.ROWBOAT.name) ?: ShipType.ROWBOAT.name
        val ship = try { ShipType.valueOf(shipStr) } catch (_: Exception) { ShipType.ROWBOAT }

        val upgStr = prefs.getString("upgrades", null)
        val upgrades = if (upgStr != null) {
            try {
                val obj = JSONObject(upgStr)
                ShipUpgrades(
                    hullLevel = obj.optInt("hull", 1),
                    sailsLevel = obj.optInt("sails", 1),
                    cannonsLevel = obj.optInt("cannons", 1),
                    cargoLevel = obj.optInt("cargo", 1)
                )
            } catch (_: Exception) { ShipUpgrades() }
        } else ShipUpgrades()

        val crewList = mutableListOf<CrewMember>()
        prefs.getString("crew", null)?.let { str ->
            try {
                val array = JSONArray(str)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val roleStr = obj.getString("role")
                    val role = CrewRole.valueOf(roleStr)
                    crewList.add(CrewMember(role, obj.optInt("level", 1)))
                }
            } catch (_: Exception) {}
        }

        val fishList = mutableListOf<CaughtFish>()
        prefs.getString("fish", null)?.let { str ->
            try {
                val array = JSONArray(str)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    fishList.add(
                        CaughtFish(
                            id = obj.optString("id", System.currentTimeMillis().toString()),
                            name = obj.getString("name"),
                            rarity = FishRarity.valueOf(obj.getString("rarity")),
                            weightKg = obj.getDouble("weight").toFloat(),
                            value = obj.getInt("value")
                        )
                    )
                }
            } catch (_: Exception) {}
        }

        return PlayerSaveData(
            level = level,
            xp = xp,
            gold = gold,
            wood = wood,
            iron = iron,
            currentShip = ship,
            upgrades = upgrades,
            crew = crewList,
            cargoFish = fishList
        )
    }

    fun reset() {
        prefs.edit().clear().apply()
    }
}
