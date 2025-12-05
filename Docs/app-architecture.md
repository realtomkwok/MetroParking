# App Architecture

## 
```text
┌─────────────────────────────────┐
│   Views (SwiftUI)               │ ← ContentView.swift
│   - Display data                │
│   - User interactions           │
└─────────────────────────────────┘
            ↓ ↑
┌─────────────────────────────────┐
│   Utilities & Helpers           │ ← SortOption.swift
│   - Sorting logic               │
│   - Filtering helpers           │
└─────────────────────────────────┘
            ↓ ↑
┌─────────────────────────────────┐
│   Data Manager/Repository       │ ← FacilityManager.swift
│   - CRUD operations             │
│   - Data fetching/refresh       │
│   - SwiftData context           │
└─────────────────────────────────┘
            ↓ ↑
┌─────────────────────────────────┐
│   Models (SwiftData)            │ ← ParkingFacility.swift
│   - Data structure              │
│   - Computed properties         │
└─────────────────────────────────┘

```