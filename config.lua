Config = {}

Config.Duration = 25                 -- secondes avant que la voiture fantôme disparaisse
Config.SpawnDistance = 70.0          -- distance de spawn de la voiture autour du joueur
Config.CarModels = { `cerberus` }      -- modèles possibles (romero = corbillard), un au hasard
Config.DriverModel = `a_m_m_skater_01` -- conducteur invisible (obligatoire pour que la voiture roule)

-- Look fantôme
Config.GhostAlpha = 130              -- transparence (255 = opaque), avec clignotement aléatoire
Config.GhostColor = { 220, 225, 255 } -- couleur de la carrosserie (RVB)

-- Performances
Config.TopSpeedBoost = 100.0         -- bonus de vitesse max du modèle en %
Config.EnginePower = 60.0            -- multiplicateur de puissance moteur
Config.TargetSpeed = 50.0            -- vitesse visée en m/s (50 = 180 km/h, 70 = 250 km/h)
Config.Acceleration = 25.0           -- accélération forcée en m/s² (plus haut = démarre plus fort)
Config.StuckTimeout = 3000           -- ms bloquée avant d'être replacée sur une route

-- Impact
Config.ImpactDistance = 2.8          -- distance d'impact si le joueur est à pied
Config.ImpactDistanceVehicle = 4.5   -- distance d'impact si le joueur est en véhicule
Config.KnockOut = true               -- à l'impact : le joueur tombe KO (ne meurt pas)
Config.KODuration = 8000             -- durée du KO en ms
Config.KOFade = true                 -- écran qui noircit pendant le KO
Config.EjectOnImpact = true          -- si le joueur est en véhicule : il est éjecté puis KO
Config.ProtectDistance = 15.0        -- invincibilité temporaire quand la voiture est à cette distance
Config.PedForce = 25.0               -- force de projection d'un joueur à pied
Config.VehicleForce = 30.0           -- force de projection d'un véhicule percuté

-- Groupes autorisés à lancer la commande
Config.AdminGroups = { 'fondateur' }

-- Event aléatoire automatique (mettre false pour désactiver)
Config.RandomEvent = {
    enabled = false,
    minMinutes = 20,
    maxMinutes = 45,
}
