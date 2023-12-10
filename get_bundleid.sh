#!/usr/bin/env bash

output=$(xcodebuild "-project" "$PROJECT_FILE" "-target" "$BITRISE_SCHEME" "-configuration" "Release" "-showBuildSettings")
[ "$is_debug" = "yes" ] && echo "To identify Bundle ID will be used this command:"
[ "$is_debug" = "yes" ] && echo 'xcodebuild "-project" "$PROJECT_FILE" "-target" "$BITRISE_SCHEME" "-configuration" "Release" "-showBuildSettings"'

# Find the line containing PRODUCT_BUNDLE_IDENTIFIER and extract its value
bundle_identifier=$(echo "$output" | grep PRODUCT_BUNDLE_IDENTIFIER | cut -d '=' -f2 | xargs)

# Export the PRODUCT_BUNDLE_IDENTIFIER environment variable
export PRODUCT_BUNDLE_IDENTIFIER="$bundle_identifier"

# Optional: Display the value (for verification)
[ "$is_debug" = "yes" ] && echo "PRODUCT_BUNDLE_IDENTIFIER: $PRODUCT_BUNDLE_IDENTIFIER"