#!/bin/bash
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8

FORMATTED_PRIVATE_KEY=$(echo "$APPLE_PRIVATE_KEY" | awk 'ORS="\\n"')

# Check if md5sum is installed
if ! command -v md5sum &> /dev/null; then
    echo "md5sum could not be found. Installing..."
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        echo "Homebrew is not installed."
        echo "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" &> /dev/null
    else
        # Install md5sum via Homebrew
        brew install md5sha1sum &> /dev/null
    fi
else
    echo "md5sum is already installed."
fi
  
#Generate paybonus scheme
paybonus=$(echo "paybonus$(( (0x$(echo -n "$APP_ID" | md5sum | cut -c 1-8) % 45) + 1 ))")

if [ -n "${BITRISE_TARGET}" ]; then
    FASTLANE_SCHEME=$BITRISE_TARGET
    [ "$is_debug" = "yes" ] && echo "For Fastlane will be used BITRISE_TARGET"
else
    FASTLANE_SCHEME=$BITRISE_SCHEME
    [ "$is_debug" = "yes" ] && echo "For Fastlane will be used BITRISE_SCHEME"
fi

rm -rf "./fastlane"
mkdir "./fastlane"

cat << EOF > "./fastlane/changelog.txt"
- Improved Performance: Faster, smoother app experience
- New Functionalities: Intuitive and user-friendly
- Refreshed Design: Enhanced user interface
- Bug Fixes: Minor issues resolved for seamless use
- Enhanced Security: Updated to protect your data
EOF

cat << EOF > "./fastlane/key.json"
{
  "key_id": "$APPLE_KEY_ID",
  "issuer_id": "$APPLE_ISSUER_ID",
  "key": "$FORMATTED_PRIVATE_KEY",
  "duration": 1200,
  "in_house": false
}
EOF

cat << EOF > "./fastlane/Fastfile"
lane :update_encryption_settings do
  update_info_plist(
    scheme: "$FASTLANE_SCHEME",
    xcodeproj: "$PROJECT_FILE",
    block: proc do |plist|
      plist['ITSAppUsesNonExemptEncryption'] = false
    end
  )
end
lane :update_build_version do
  update_info_plist(
    scheme: "$FASTLANE_SCHEME",
    xcodeproj: "$PROJECT_FILE",
    block: proc do |plist|
      plist['CFBundleVersion'] = '$BITRISE_BUILD_NUMBER'
      plist['CFBundleShortVersionString'] = '$APP_VERSION'
    end
  )
end
lane :add_paybonus_scheme do
  update_info_plist(
    scheme: "$FASTLANE_SCHEME",
    xcodeproj: "$PROJECT_FILE",
    block: proc do |plist|
      plist['CFBundleURLTypes'] ||= []
      plist['CFBundleURLTypes'] << {
        'CFBundleURLSchemes' => ['$paybonus']
      }
    end
  )
end
EOF

need_comit=0

# Check for "ITSAppUsesNonExemptEncryption" and update encryption settings if not found
if ! grep -q "ITSAppUsesNonExemptEncryption" "$INFOPLIST_FILE"; then
  if [ "$is_debug" = "yes" ]; then
    fastlane update_encryption_settings
    echo "Fastlane update_encryption_settings finished"
  else
    fastlane update_encryption_settings >/dev/null 2>&1
    echo "Fastlane update_encryption_settings finished"
  fi
  need_comit=1
else
  echo "ITSAppUsesNonExemptEncryption encryption settings found, no need to add"
fi

# Check for "paybonus" and add paybonus scheme if not found
if ! grep -q "paybonus" "$INFOPLIST_FILE"; then
  if [ "$is_debug" = "yes" ]; then
    fastlane add_paybonus_scheme
    echo "Fastlane add_paybonus_scheme finished. URLScheme is: $paybonus"
  else
    fastlane add_paybonus_scheme >/dev/null 2>&1
    echo "Fastlane add_paybonus_scheme finished"
  fi
  need_comit=1
else
  echo "Paybonus URLscheme found, no need to add. URLScheme is: $paybonus"
fi

# Commit changes to repo if needed
if [ "$need_comit" = 1 ]; then
    # Add all changes to the staging area except fastlane
    git add . && git reset -- fastlane/ pubspec.yaml

    # Commit the changes
    read commitMessage
    git commit -m "Bitrise comit"

    # Push the changes to the remote repository
    echo "Pushing to remote repository..."
    git config --global push.default current
    git config push.default current
    git push

    echo "Changes committed and pushed to remote repository successfully."
fi


#Update version and build numbers
if [ "$is_debug" = "yes" ]; then
  fastlane update_build_version
  echo "Fastlane updated build and version numbers"
else
  fastlane update_build_version >/dev/null 2>&1
  echo "Fastlane updated build and version numbers"
fi

#Update what's new only if status PREPARE_FOR_SUBMISSION, update_whats_new = yes and this is "appstore-release" workflow
if [ "$update_whats_new" = "yes" ] && [ "$APP_STATUS" = "PREPARE_FOR_SUBMISSION" ] && { [ "$BITRISE_TRIGGERED_WORKFLOW_TITLE" = "appstore-release" ] || [ "$BITRISE_TRIGGERED_WORKFLOW_TITLE" = "deploy" ]; }; then
    case "$APP_VERSION" in
        "1.0"|"1.0.0"|"0.0.0"|"0.0")
            [ "$is_debug" = "yes" ] && echo "It's a first App version, What's new will not be updated"
            ;;
        *)
            if [ "$is_debug" = "yes" ]; then
              fastlane run set_changelog api_key_path:"./fastlane/key.json" version:"$APP_VERSION" app_identifier:"$PRODUCT_BUNDLE_IDENTIFIER" || true
            else
              fastlane run set_changelog api_key_path:"./fastlane/key.json" version:"$APP_VERSION" app_identifier:"$PRODUCT_BUNDLE_IDENTIFIER" >/dev/null 2>&1 || true
            fi
            ;;
    esac
fi

rm -rf "./fastlane"