# Environment Configuration Setup

This document explains how to set up environment variables for the MetroParking app.

## Quick Setup

1. **Copy the template:**
   ```bash
   cp .env.template .env
   ```

2. **Edit the `.env` file** with your actual values:
   ```env
   TFNSW_API_KEY=your_actual_tfnsw_api_key_here
   CAR_PARK_BASE_URL=https://api.transport.nsw.gov.au/v1
   SUPABASE_URL=your_actual_supabase_url_here
   SUPABASE_PUBLISHABLE_KEY=your_actual_supabase_key_here
   ENVIRONMENT=development
   ```

3. **Add the .env file to your Xcode project:**
    - In Xcode, right-click your project
    - Select "Add Files to [Project Name]"
    - Choose the `.env` file
    - **Important:** Make sure "Add to target" is checked for your main app target

## Environment Variables

| Variable                   | Description                                       | Required                     |
|----------------------------|---------------------------------------------------|------------------------------|
| `TFNSW_API_KEY`            | Transport for NSW API key                         | Yes                          |
| `CAR_PARK_BASE_URL`        | Base URL for car park API                         | No (has default)             |
| `SUPABASE_URL`             | Your Supabase project URL                         | Yes                          |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase publishable key                          | Yes                          |
| `ENVIRONMENT`              | Environment type (development/staging/production) | No (defaults to development) |

## Security Notes

- ✅ The `.env` file is in `.gitignore` and won't be committed to version control
- ✅ Sensitive values are masked in debug output
- ✅ The app has fallback support for Info.plist values for backwards compatibility
- ⚠️ Never commit actual API keys or sensitive data to your repository

## Different Environments

You can create different environment files:

- `.env` - Default environment
- `.env.development` - Development specific
- `.env.staging` - Staging environment
- `.env.production` - Production environment

The EnvironmentManager will load variables in this order:

1. `.env` file
2. System environment variables (override .env values)

## Troubleshooting

### App crashes with "missing environment variable" error

1. Check that your `.env` file exists
2. Verify all required variables are set
3. Ensure the `.env` file is added to your Xcode target
4. Run `Configuration.validateConfiguration()` to check all values

### Variables not loading

1. Verify `.env` file format (KEY=VALUE, no spaces around =)
2. Check for typos in variable names
3. Ensure no quotes around values unless needed
4. Check that the file is properly added to the Xcode project

### Build issues

1. Clean build folder (⇧⌘K)
2. Restart Xcode
3. Verify `.env` file is included in the bundle

## Testing Configuration

Add this to your app startup code to validate configuration:

```swift
// In your App.swift or main entry point
do {
    try Configuration.validateConfiguration()
    Configuration.printConfiguration()
} catch {
    print("❌ Configuration error: \(error)")
}
```