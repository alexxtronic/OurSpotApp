# Developer Notes & Project Context
> **READ THIS FIRST**: This document contains critical context about the codebase history, rebranding, and build system.

## 1. Project Identity: "FriendMap" vs "OurSpot"
- **Internal Name**: `FriendMap` (used in file paths, folders, database schemas).
- **Public Name**: `OurSpot` (used in App Store, Display Name, Branding).
- **Reason**: The project was renamed mid-flight. Do NOT rename the `ios/FriendMap` folder structure as it will break git history and imports.
- **Xcode Project**: The project file is named `OurSpot.xcodeproj` but is generated from `project.yml`.

## 2. The "Orange Theme" Incident (Jan 16, 2026)
- **What Happened**: The code for the "Orange" (Dark Gold) rebranding and "Realistic Icons" feature was lost in a `git stash` on a feature branch (`feature/architecture-cleanup`), leading to a "Zombie App" diagnosis where the build didn't match the expected UI.
- **Resolution**: The stash was recovered and applied.
- **Key Takeaway**: If the app looks "Purple" or has "Emoji Pins", you are on the WRONG version. The correct version has:
    - `DesignSystem.Colors.primary` = `Color(hex: "cc990c")` (Dark Gold/Orange)
    - `MapView` uses `Image(plan.activityType.realisticIconName)` instead of `Text`.

## 3. Build System: XcodeGen
- **Crucial**: We use `xcodegen` to generate the `.xcodeproj` file.
- **Do NOT** manually edit `project.pbxproj` extensively.
- **To Change Project Settings**: Edit `ios/project.yml`.
- **To Regenerate Project**: Run `xcodegen generate` in the `ios/` directory.
- **Signing**: `DEVELOPMENT_TEAM` is set to `HFC498ZVXN` in `project.yml` (was empty until a July 2026 session fixed it — see `UPDATES.md` — empty `DEVELOPMENT_TEAM` makes `xcodebuild archive` fail outright).

## 4. UI Architecture
- **DesignSystem**: Located in `ios/FriendMap/Views/Components/DesignSystem.swift`. ALWAYS use this for colors and fonts. Do not hardcode colors.
- **Icons**:
    - **Realistic Icons**: 3D Rendered PNGs in `Assets.xcassets/ActivityIcons`.
    - **Mapped in**: `ActivityType.swift` (`realisticIconName` property).

## 5. Branching Strategy
- **Current Active Branch**: `feature/architecture-cleanup` (contains the latest Orange/OurSpot code).
- **Main**: Historical main branch.

## 6. Website
- **Location**: `friendmap/website`
- **Tech**: React + Vite + Tailwind (managed via `index.css` mostly).
- **Deployment**: GitHub Pages.
- **Note**: `dist/` and `node_modules/` are ignored.

## 7. Backend Recovery & Security Hardening (July 2026)
- **See `UPDATES.md`** for a full log: the original Supabase project died (paused >90 days,
  unrecoverable), the app was migrated to a new project (`ammeeipxspudkbsrtkyn`) with a
  from-scratch schema apply, an RLS infinite-recursion bug and a real device-token-leak
  vulnerability were found and fixed, and a string of "silent failure" bugs (plan
  creation/deletion, avatar upload, an orphaned-profile account lockout) were diagnosed and
  fixed with live verification against the database.
- **Current migration count**: 31 (`backend/migrations/001` through `031`). Check
  `UPDATES.md`'s "Current State" section before assuming any given migration has actually
  been applied to the live project — this session authored several that still needed
  manual confirmation.
