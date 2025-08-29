# Configuration

## Prerequisites

- iOS 18.4+
- Xcode 16.3+
- TfNSW API Key ([Get one here](https://opendata.transport.nsw.gov.au/))
- Apple Developer Account (for code signing)

## Quick Setup

### 1. Clone and Configure

```bash
git clone <repository-url>
cd MetroParking

# Copy the configuration template
cp Config.xcconfig.template Config.xcconfig
```

### 2. Edit Your Configuration

Open `Config.xcconfig` in any text editor and fill in your values:

```bash
// TfNSW API Configuration (REQUIRED)
TFNSW_API_KEY=your_actual_tfnsw_api_key_here
CAR_PARK_BASE_URL=https://api.transport.nsw.gov.au/v1

// Supabase Configuration (OPTIONAL - for analytics features)
SUPABASE_URL=your_supabase_project_url
SUPABASE_PUBLISHABLE_KEY=your_supabase_anon_key

// Development Configuration (REQUIRED)
DEVELOPMENT_TEAM=your_apple_developer_team_id
```

### 3. Build and Run

```bash
open MetroParking.xcodeproj
```

Hit ⌘+R. Done.

## Configuration Details

### Required Settings

**TFNSW_API_KEY**: Your Transport for NSW API key

- Get it from: https://opendata.transport.nsw.gov.au/
- The app will crash at startup if this is missing or invalid

**DEVELOPMENT_TEAM**: Your Apple Developer Team ID

- Found in your Apple Developer account
- Required for code signing

### Optional Settings

**SUPABASE_URL** & **SUPABASE_PUBLISHABLE_KEY**:

- Only needed if you want historical parking trend charts
- Leave empty to disable analytics features
- The app works fine without these

**CAR_PARK_BASE_URL**:

- Defaults to `https://api.transport.nsw.gov.au/v1`
- Only change if you know what you're doing

## Troubleshooting

### "TFNSW_API_KEY not configured" crash

- Make sure `Config.xcconfig` exists
- Check that your API key doesn't contain `YOUR_` or placeholder text
- Verify the key is at least 16 characters

### Code signing issues

- Verify your `DEVELOPMENT_TEAM` is correct
- Make sure you're signed in to Xcode with your Apple ID
- Check that your team has the necessary certificates

### Build configuration not found

- Ensure `Config.xcconfig` is in the project root
- The file should be next to `MetroParking.xcodeproj`
- Don't put it inside the MetroParking folder

## Security Notes

- `Config.xcconfig` is in `.gitignore` - your secrets won't be committed
- Values are embedded in the final binary (this is normal for mobile apps)
- The template file (`Config.xcconfig.template`) is safe to commit

## For Contributors

If you're contributing to the project:

1. Never commit your actual `Config.xcconfig` file
2. Use the template to create your local configuration
3. All configuration loading happens in `Configuration.swift`
4. Add new config keys to both the template and Configuration.swift