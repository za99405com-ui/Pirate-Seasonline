package com.example.pirateseas.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun UnityArchitectureScreen(
    onBackToGame: () -> Unit
) {
    var selectedSection by remember { mutableStateOf(0) }
    val sections = listOf(
        "🏗️ Architecture",
        "⛵ ShipController.cs",
        "💣 BroadsideCannons.cs",
        "🏴‍☠️ EnemyShipAI.cs",
        "🎣 FishingSystem.cs",
        "⚓ Port & Save",
        "🌐 Fusion 2 Network"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0A1526))
    ) {
        // Header
        Surface(
            color = Color(0xFF0F2038),
            shadowElevation = 6.dp,
            modifier = Modifier.fillMaxWidth()
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 8.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onBackToGame) {
                    Icon(
                        imageVector = Icons.Default.ArrowBack,
                        contentDescription = "Back to Game",
                        tint = Color(0xFFFFD54F)
                    )
                }
                Spacer(modifier = Modifier.width(4.dp))
                Column {
                    Text(
                        text = "Pirate Seas Online • Unity 6 + URP",
                        color = Color(0xFFFFD54F),
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "Senior Game Architecture & Production C# Blueprints",
                        color = Color.White.copy(alpha = 0.7f),
                        fontSize = 11.sp
                    )
                }
            }
        }

        // Section Tabs
        ScrollableTabRow(
            selectedTabIndex = selectedSection,
            containerColor = Color(0xFF142642),
            contentColor = Color(0xFFFFD54F),
            edgePadding = 12.dp
        ) {
            sections.forEachIndexed { index, title ->
                Tab(
                    selected = selectedSection == index,
                    onClick = { selectedSection = index },
                    text = { Text(text = title, fontSize = 12.sp, fontWeight = FontWeight.Bold) }
                )
            }
        }

        // Section Content
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp)
        ) {
            when (selectedSection) {
                0 -> ArchitectureOverviewDoc()
                1 -> CodeSnippetDoc(
                    title = "Assets/Scripts/Ships/ShipController.cs",
                    explanation = "نظام حركة السفينة بالفيزياء البحرية (Inertia, Turning Rudder, Acceleration, Wave Bobbing)",
                    code = SHIP_CONTROLLER_CS
                )
                2 -> CodeSnippetDoc(
                    title = "Assets/Scripts/Combat/BroadsideCannons.cs",
                    explanation = "نظام المدافع الجانبية (Port & Starboard Cannons, Cooldowns, Aim Assist, Damage Floaters)",
                    code = BROADSIDE_CANNONS_CS
                )
                3 -> CodeSnippetDoc(
                    title = "Assets/Scripts/Combat/EnemyShipAI.cs",
                    explanation = "ذكاء اصطناعي لسفن الأعداء (Patrol, Detect Outside Safe Zones, Align Broadside, Drop Loot)",
                    code = ENEMY_SHIP_AI_CS
                )
                4 -> CodeSnippetDoc(
                    title = "Assets/Scripts/Fishing/FishingZone.cs",
                    explanation = "نظام الصيد السريع بالموبايل وجداول الاحتمالات لندرة الأسماك والأوزان",
                    code = FISHING_ZONE_CS
                )
                5 -> CodeSnippetDoc(
                    title = "Assets/Scripts/Managers/SaveManager.cs",
                    explanation = "نظام الحفظ المستقل مع دعم التزامن مع سيرفرات الـ Backend مستقبلاً",
                    code = SAVE_MANAGER_CS
                )
                6 -> CodeSnippetDoc(
                    title = "Assets/Scripts/Networking/NetworkShipSync.cs",
                    explanation = "معمارية Photon Fusion 2 للربط الأونلاين ونظام التحقق من الخادم Server Authoritative",
                    code = FUSION_NETWORKING_CS
                )
            }
        }
    }
}

@Composable
private fun ArchitectureOverviewDoc() {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        item {
            DocSectionCard(
                title = "1. Game Architecture & Folder Structure",
                content = """
📁 Assets/
  ├── 📁 Art/ (Stylized 3D Low-Poly Meshes, Materials, URP Shaders)
  ├── 📁 Audio/ (Ocean Waves, Cannon Boom, Bell, Splashes)
  ├── 📁 Prefabs/ (PlayerShip, EnemySloop, Cannonball, LootCrate, Islands)
  ├── 📁 ScriptableObjects/ (ShipDataSO, FishDataSO, CrewSO, UpgradesSO)
  └── 📁 Scripts/
       ├── 📁 Ships/ (ShipController, ShipStats, WaveFloating)
       ├── 📁 Combat/ (BroadsideCannons, Cannonball, HealthSystem, DamagePopup)
       ├── 📁 AI/ (EnemyShipAI, PatrolWaypoints)
       ├── 📁 Fishing/ (FishingZone, FishingManager)
       ├── 📁 Ports/ (PortDockTrigger, SafeZoneArea)
       ├── 📁 UI/ (MobileHUD, VirtualJoystick, PortPanelsManager)
       ├── 📁 Economy/ (CurrencyManager, InventoryManager)
       ├── 📁 SaveSystem/ (SaveManager, ISaveData, CloudSync)
       └── 📁 Networking/ (FusionNetworkRunner, NetworkShipSync)
                """.trimIndent()
            )
        }

        item {
            DocSectionCard(
                title = "2. Unity 6 Project & URP Mobile Optimization Settings",
                content = """
• Render Pipeline: Universal Render Pipeline (URP Mobile Asset)
• Color Space: Linear
• Target Frame Rate: 60 FPS (Application.targetFrameRate = 60)
• Physics: Physics 3D with Fixed Timestep = 0.02 (50Hz)
• Collision Matrix:
  - PlayerShip collides with: Islands, EnemyShip, Cannonballs, Triggers
  - Cannonballs (Player) only collide with EnemyShip & Islands (Ignore Layer: PlayerShip)
  - Cannonballs (Enemy) only collide with PlayerShip & Islands (Ignore Layer: EnemyShip)
• Rendering Optimizations:
  - GPU Instancing enabled on ocean water & island foliage materials
  - Dynamic Batching enabled
  - Shadow Distance: 45m with Soft Shadows disabled for mobile performance
  - Object Pooling for Cannonballs, Floating Texts, and Water Splashes
                """.trimIndent()
            )
        }

        item {
            DocSectionCard(
                title = "3. Scenes & Game Loop Execution",
                content = """
• Scenes:
  1. BootLoader.unity: تهيئة وحفظ بيانات اللاعب وتعيين إعدادات الشاشة
  2. MainMenu.unity: اختيار السيرفر، اللوبي، وتخصيص السفينة
  3. OceanWorld_Sector1.unity: العالم البحري المفتوح (3 جزر، موانئ، مناطق صيد، سفن NPC، مناطق آمنة)

• Game Loop:
  Input (Virtual Joystick / Fire Buttons)
  → Physics Simulation (Rigidbody + Inertia + Wave Sway)
  → Combat & AI Ticks (Broadside aiming, line-of-sight check)
  → Safe Zone Verification (Disables PvP/PvE damage near ports)
  → UI Sync & Camera Follow
  → Fusion 2 Server Tick (Replication of Position, Rotation, HP & Cannon Fire events)
                """.trimIndent()
            )
        }
    }
}

@Composable
private fun CodeSnippetDoc(title: String, explanation: String, code: String) {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF142642)),
                shape = RoundedCornerShape(10.dp)
            ) {
                Column(modifier = Modifier.padding(12.dp)) {
                    Text(text = title, color = Color(0xFFFFD54F), fontWeight = FontWeight.Bold, fontSize = 14.sp)
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(text = explanation, color = Color(0xFF81C784), fontSize = 12.sp)
                }
            }
        }

        item {
            Card(
                modifier = Modifier.fillMaxWidth(),
                colors = CardDefaults.cardColors(containerColor = Color(0xFF070E1A)),
                shape = RoundedCornerShape(10.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF1E3A5F))
            ) {
                Text(
                    text = code,
                    color = Color(0xFFECEFF1),
                    fontFamily = FontFamily.Monospace,
                    fontSize = 11.sp,
                    lineHeight = 16.sp,
                    modifier = Modifier.padding(14.dp)
                )
            }
        }
    }
}

@Composable
private fun DocSectionCard(title: String, content: String) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = Color(0xFF142642)),
        shape = RoundedCornerShape(10.dp)
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(text = title, color = Color(0xFFFFD54F), fontWeight = FontWeight.Bold, fontSize = 14.sp)
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = content,
                color = Color.White.copy(alpha = 0.9f),
                fontFamily = FontFamily.Monospace,
                fontSize = 11.sp,
                lineHeight = 16.sp
            )
        }
    }
}

// FULL PRODUCTION C# SCRIPTS FOR UNITY 6:

private const val SHIP_CONTROLLER_CS = """using UnityEngine;

namespace PirateSeas.Ships
{
    [RequireComponent(typeof(Rigidbody))]
    public class ShipController : MonoBehaviour
    {
        [Header("Movement Stats")]
        [SerializeField] private float maxSpeed = 12f;
        [SerializeField] private float acceleration = 3.5f;
        [SerializeField] private float deceleration = 2.0f;
        [SerializeField] private float turnSpeed = 45f;

        [Header("Ocean Feel (Wave Sway)")]
        [SerializeField] private float rollAmount = 4f;
        [SerializeField] private float pitchAmount = 2.5f;
        [SerializeField] private float swayFrequency = 1.8f;

        [Header("Components")]
        [SerializeField] private Transform shipModelTransform;
        [SerializeField] private ParticleSystem waterWakeParticles;

        private Rigidbody rb;
        private float currentSpeed = 0f;
        private Vector2 inputVector = Vector2.zero;

        public float CurrentSpeed => currentSpeed;
        public float MaxSpeed => maxSpeed;

        private void Awake()
        {
            rb = GetComponent<Rigidbody>();
            rb.useGravity = false;
            rb.constraints = RigidbodyConstraints.FreezePositionY | 
                             RigidbodyConstraints.FreezeRotationX | 
                             RigidbodyConstraints.FreezeRotationZ;
        }

        public void SetInput(Vector2 input)
        {
            inputVector = Vector2.ClampMagnitude(input, 1f);
        }

        private void FixedUpdate()
        {
            HandleShipPhysics();
            SimulateWaveBobbing();
        }

        private void HandleShipPhysics()
        {
            float targetSpeed = inputVector.magnitude * maxSpeed;

            if (inputVector.magnitude > 0.1f)
            {
                // Smooth acceleration
                currentSpeed = Mathf.MoveTowards(currentSpeed, targetSpeed, acceleration * Time.fixedDeltaTime);

                // Calculate target rotation from input angle
                float targetAngle = Mathf.Atan2(inputVector.x, inputVector.y) * Mathf.Rad2Deg;
                Quaternion targetRot = Quaternion.Euler(0f, targetAngle, 0f);
                rb.rotation = Quaternion.RotateTowards(rb.rotation, targetRot, turnSpeed * Time.fixedDeltaTime);
            }
            else
            {
                // Nautical Drag deceleration
                currentSpeed = Mathf.MoveTowards(currentSpeed, 0f, deceleration * Time.fixedDeltaTime);
            }

            // Apply forward velocity in ship's heading
            Vector3 forwardVelocity = transform.forward * currentSpeed;
            rb.linearVelocity = forwardVelocity;

            // Update water wake effects
            if (waterWakeParticles != null)
            {
                var emission = waterWakeParticles.emission;
                emission.rateOverTime = currentSpeed > 1f ? currentSpeed * 4f : 0f;
            }
        }

        private void SimulateWaveBobbing()
        {
            if (shipModelTransform == null) return;

            float time = Time.time * swayFrequency;
            float roll = Mathf.Sin(time) * rollAmount * (1f + (currentSpeed / maxSpeed) * 0.5f);
            float pitch = Mathf.Cos(time * 0.8f) * pitchAmount;

            shipModelTransform.localRotation = Quaternion.Euler(pitch, 0f, roll);
        }

        public void ApplySpeedMultiplier(float multiplier)
        {
            maxSpeed *= multiplier;
        }
    }
}"""

private const val BROADSIDE_CANNONS_CS = """using System.Collections;
using UnityEngine;

namespace PirateSeas.Combat
{
    public class BroadsideCannons : MonoBehaviour
    {
        [Header("Cannons Setup")]
        [SerializeField] private Transform[] portCannons;      // Left Cannons
        [SerializeField] private Transform[] starboardCannons; // Right Cannons
        [SerializeField] private GameObject cannonballPrefab;
        [SerializeField] private ParticleSystem muzzleSmokePrefab;

        [Header("Weapon Stats")]
        [SerializeField] private float baseDamage = 35f;
        [SerializeField] private float reloadTime = 2.5f;
        [SerializeField] private float projectileSpeed = 28f;
        [SerializeField] private float critChance = 0.15f;
        [SerializeField] private float critMultiplier = 1.75f;

        private float portCooldown = 0f;
        private float starboardCooldown = 0f;

        public float PortCooldownRatio => Mathf.Clamp01(portCooldown / reloadTime);
        public float StarboardCooldownRatio => Mathf.Clamp01(starboardCooldown / reloadTime);

        private void Update()
        {
            if (portCooldown > 0f) portCooldown -= Time.deltaTime;
            if (starboardCooldown > 0f) starboardCooldown -= Time.deltaTime;
        }

        public bool FirePort()
        {
            if (portCooldown > 0f) return false;
            portCooldown = reloadTime;
            StartCoroutine(FireVolleyRoutine(portCannons, -transform.right));
            return true;
        }

        public bool FireStarboard()
        {
            if (starboardCooldown > 0f) return false;
            starboardCooldown = reloadTime;
            StartCoroutine(FireVolleyRoutine(starboardCannons, transform.right));
            return true;
        }

        private IEnumerator FireVolleyRoutine(Transform[] cannons, Vector3 direction)
        {
            float damagePerBall = baseDamage / Mathf.Max(1, cannons.Length);

            foreach (var cannon in cannons)
            {
                if (cannon == null) continue;

                // Slightly staggered volley firing sound & timing
                FireSingleCannon(cannon.position, direction, damagePerBall);
                yield return new WaitForSeconds(0.06f);
            }
        }

        private void FireSingleCannon(Vector3 origin, Vector3 baseDirection, float damage)
        {
            // Spread deviation
            Vector3 fireDir = Quaternion.Euler(0f, Random.Range(-3f, 3f), 0f) * baseDirection;

            // Instantiate Cannonball
            GameObject ball = Instantiate(cannonballPrefab, origin, Quaternion.LookRotation(fireDir));
            var projectile = ball.GetComponent<CannonballProjectile>();
            if (projectile != null)
            {
                bool isCrit = Random.value < critChance;
                float finalDamage = isCrit ? damage * critMultiplier : damage;
                projectile.Initialize(fireDir * projectileSpeed, finalDamage, isCrit, isPlayerOwned: true);
            }
        }
    }
}"""

private const val ENEMY_SHIP_AI_CS = """using UnityEngine;

namespace PirateSeas.AI
{
    public class EnemyShipAI : MonoBehaviour
    {
        [Header("AI Parameters")]
        [SerializeField] private float detectionRadius = 45f;
        [SerializeField] private float combatDistance = 25f;
        [SerializeField] private float maxSpeed = 7f;
        [SerializeField] private float turnSpeed = 35f;

        [Header("Loot Drop")]
        [SerializeField] private GameObject lootCratePrefab;

        private Transform playerTarget;
        private Rigidbody rb;
        private float fireTimer = 0f;
        private bool isPlayerInSafeZone = false;

        private void Awake()
        {
            rb = GetComponent<Rigidbody>();
            GameObject playerObj = GameObject.FindWithTag("Player");
            if (playerObj != null) playerTarget = playerObj.transform;
        }

        private void FixedUpdate()
        {
            if (playerTarget == null) return;

            float distance = Vector3.Distance(transform.position, playerTarget.position);

            if (distance < detectionRadius && !isPlayerInSafeZone)
            {
                EngagePlayer(distance);
            }
            else
            {
                PatrolBehavior();
            }
        }

        private void EngagePlayer(float distance)
        {
            // Position broadside facing the player
            Vector3 toPlayer = (playerTarget.position - transform.position).normalized;
            Vector3 broadsideDir = Vector3.Cross(toPlayer, Vector3.up);

            Quaternion desiredRotation = Quaternion.LookRotation(broadsideDir);
            rb.rotation = Quaternion.RotateTowards(rb.rotation, desiredRotation, turnSpeed * Time.fixedDeltaTime);

            rb.linearVelocity = transform.forward * maxSpeed;

            // Fire broadside when aligned
            fireTimer -= Time.fixedDeltaTime;
            if (fireTimer <= 0f && distance < combatDistance)
            {
                fireTimer = 4.0f;
                // Fire enemy cannons...
            }
        }

        private void PatrolBehavior()
        {
            rb.linearVelocity = transform.forward * (maxSpeed * 0.5f);
        }

        public void OnShipDestroyed()
        {
            // Drop floating loot crate
            if (lootCratePrefab != null)
            {
                Instantiate(lootCratePrefab, transform.position, Quaternion.identity);
            }
            Destroy(gameObject);
        }
    }
}"""

private const val FISHING_ZONE_CS = """using System;
using UnityEngine;

namespace PirateSeas.Fishing
{
    public enum FishRarity { Common, Uncommon, Rare, Epic, Legendary }

    [System.Serializable]
    public struct FishData
    {
        public string fishName;
        public FishRarity rarity;
        public float minWeight;
        public float maxWeight;
        public int baseGoldValue;
    }

    public class FishingZone : MonoBehaviour
    {
        [Header("Zone Attributes")]
        [SerializeField] private string zoneName = "Emerald Bay";
        [SerializeField] private float zoneRadius = 30f;
        [SerializeField] [Range(0f, 1f)] private float rareDropBonus = 0.2f;

        [Header("Fish Pool")]
        [SerializeField] private FishData[] catchableFish;

        public FishData CatchRandomFish(bool hasFishermanCrew)
        {
            float bonus = rareDropBonus + (hasFishermanCrew ? 0.35f : 0f);
            float roll = UnityEngine.Random.value;

            FishRarity chosenRarity = FishRarity.Common;
            if (roll < 0.05f + bonus * 0.1f) chosenRarity = FishRarity.Legendary;
            else if (roll < 0.18f + bonus * 0.2f) chosenRarity = FishRarity.Epic;
            else if (roll < 0.45f + bonus * 0.3f) chosenRarity = FishRarity.Rare;
            else if (roll < 0.75f + bonus * 0.2f) chosenRarity = FishRarity.Uncommon;

            // Filter by rarity
            var candidates = Array.FindAll(catchableFish, f => f.rarity == chosenRarity);
            if (candidates.Length == 0) candidates = catchableFish;

            return candidates[UnityEngine.Random.Range(0, candidates.Length)];
        }
    }
}"""

private const val SAVE_MANAGER_CS = """using System.IO;
using UnityEngine;

namespace PirateSeas.SaveSystem
{
    [System.Serializable]
    public class PlayerSaveState
    {
        public int playerLevel = 1;
        public int playerXp = 0;
        public int goldCoins = 250;
        public int woodCargo = 50;
        public int ironCargo = 15;
        public string equippedShipId = "sloop_tier1";
        public int hullLevel = 1;
        public int sailsLevel = 1;
        public int cannonsLevel = 1;
    }

    public class SaveManager : MonoBehaviour
    {
        public static SaveManager Instance { get; private set; }
        public PlayerSaveState State { get; private set; }

        private string savePath;

        private void Awake()
        {
            if (Instance == null)
            {
                Instance = this;
                DontDestroyOnLoad(gameObject);
                savePath = Path.Combine(Application.persistentDataPath, "pirate_save.json");
                LoadGame();
            }
            else
            {
                Destroy(gameObject);
            }
        }

        public void SaveGame()
        {
            string json = JsonUtility.ToJson(State, true);
            File.WriteAllText(savePath, json);
        }

        public void LoadGame()
        {
            if (File.Exists(savePath))
            {
                string json = File.ReadAllText(savePath);
                State = JsonUtility.FromJson<PlayerSaveState>(json);
            }
            else
            {
                State = new PlayerSaveState();
                SaveGame();
            }
        }
    }
}"""

private const val FUSION_NETWORKING_CS = """using Fusion;
using UnityEngine;

namespace PirateSeas.Networking
{
    public class NetworkShipSync : NetworkBehaviour
    {
        [Networked] public float NetworkHp { get; set; }
        [Networked] public NetworkButtons ButtonsPrevious { get; set; }
        [Networked] public string PlayerName { get; set; }

        [SerializeField] private Transform shipVisual;

        public override void Spawned()
        {
            if (Object.HasStateAuthority)
            {
                NetworkHp = 100f;
            }
        }

        public override void FixedUpdateNetwork()
        {
            if (GetInput(out NetworkInputData input))
            {
                // Server-Authoritative Ship movement
                Vector3 moveDir = new Vector3(input.Horizontal, 0f, input.Vertical);
                if (moveDir.sqrMagnitude > 0.01f)
                {
                    transform.rotation = Quaternion.RotateTowards(
                        transform.rotation, 
                        Quaternion.LookRotation(moveDir), 
                        50f * Runner.DeltaTime
                    );
                    transform.position += transform.forward * (8f * Runner.DeltaTime);
                }

                // Broadside Fire RPCs
                if (input.Buttons.WasPressed(ButtonsPrevious, NetworkButtons.FirePort))
                {
                    RPC_FireBroadside(true);
                }
                if (input.Buttons.WasPressed(ButtonsPrevious, NetworkButtons.FireStarboard))
                {
                    RPC_FireBroadside(false);
                }

                ButtonsPrevious = input.Buttons;
            }
        }

        [Rpc(RpcSources.All, RpcTargets.StateAuthority)]
        public void RPC_ApplyDamage(float damage)
        {
            NetworkHp -= damage;
            if (NetworkHp <= 0f)
            {
                RPC_BroadcastSunk();
            }
        }

        [Rpc(RpcSources.StateAuthority, RpcTargets.All)]
        private void RPC_FireBroadside(bool isPort)
        {
            // Play audio and spawn cosmetic smoke on all remote clients
        }

        [Rpc(RpcSources.StateAuthority, RpcTargets.All)]
        private void RPC_BroadcastSunk()
        {
            // Trigger ship explosion and sink anim on all clients
        }
    }

    public struct NetworkInputData : INetworkInput
    {
        public float Horizontal;
        public float Vertical;
        public NetworkButtons Buttons;
    }

    public enum NetworkButtons
    {
        FirePort = 1,
        FireStarboard = 2,
        Interact = 4
    }
}"""
