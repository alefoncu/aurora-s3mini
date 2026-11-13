#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
mkdir -p build
xcrun swiftc -O Sources/VehicleRig.swift Sources/Transmission.swift Sources/BikePhysics.swift Tests/PhysicsTests.swift -o build/PhysicsTests
build/PhysicsTests
xcrun swiftc -O Sources/VehicleRig.swift Sources/RiderRig.swift Tests/RiderRigTests.swift -o build/RiderRigTests
build/RiderRigTests
xcrun swiftc -O Sources/VehicleRig.swift Sources/Transmission.swift Sources/BikePhysics.swift Sources/RiderRig.swift Sources/RiderRagdoll.swift Tests/RiderRagdollTests.swift -o build/RiderRagdollTests
build/RiderRagdollTests
xcrun swiftc -O Sources/VehicleRig.swift Sources/Transmission.swift Tests/TransmissionTests.swift -o build/TransmissionTests
build/TransmissionTests
xcrun swiftc -O Sources/RideChallenges.swift Tests/ChallengeTests.swift -o build/ChallengeTests
build/ChallengeTests
xcrun swiftc -O Sources/VehicleRig.swift Sources/Transmission.swift Sources/BikePhysics.swift Sources/RideScore.swift Sources/RideCosmetics.swift Sources/RideProgress.swift Tests/ScoreTests.swift -o build/ScoreTests
build/ScoreTests
xcrun swiftc -O Sources/VehicleRig.swift Sources/Transmission.swift Sources/BikePhysics.swift Sources/RideStats.swift Sources/RideMissions.swift Sources/RideTutorial.swift Sources/RideRival.swift Sources/RideRace.swift Tests/ProgressTests.swift -o build/ProgressTests
build/ProgressTests
xcrun swiftc -O Sources/RideWeather.swift Tests/WeatherTests.swift -o build/WeatherTests
build/WeatherTests
xcrun swiftc -target "$(uname -m)-apple-macos13.0" Sources/TouchBarController.swift Tests/TouchBarTests.swift -o build/TouchBarTests
build/TouchBarTests
xcrun swiftc -parse-as-library Tests/AudioTests.swift -o build/AudioTests
build/AudioTests
