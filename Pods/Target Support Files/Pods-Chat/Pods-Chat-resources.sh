#!/bin/sh
set -e

mkdir -p "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"

RESOURCES_TO_COPY=${PODS_ROOT}/resources-to-copy-${TARGETNAME}.txt
> "$RESOURCES_TO_COPY"

install_resource()
{
  case $1 in
    *.storyboard)
      echo "ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$1\" .storyboard`.storyboardc ${PODS_ROOT}/$1 --sdk ${SDKROOT}"
      ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$1\" .storyboard`.storyboardc" "${PODS_ROOT}/$1" --sdk "${SDKROOT}"
      ;;
    *.xib)
        echo "ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile ${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$1\" .xib`.nib ${PODS_ROOT}/$1 --sdk ${SDKROOT}"
      ibtool --reference-external-strings-file --errors --warnings --notices --output-format human-readable-text --compile "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename \"$1\" .xib`.nib" "${PODS_ROOT}/$1" --sdk "${SDKROOT}"
      ;;
    *.framework)
      echo "mkdir -p ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      mkdir -p "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      echo "rsync -av ${PODS_ROOT}/$1 ${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      rsync -av "${PODS_ROOT}/$1" "${CONFIGURATION_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      ;;
    *.xcdatamodel)
      echo "xcrun momc \"${PODS_ROOT}/$1\" \"${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1"`.mom\""
      xcrun momc "${PODS_ROOT}/$1" "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1" .xcdatamodel`.mom"
      ;;
    *.xcdatamodeld)
      echo "xcrun momc \"${PODS_ROOT}/$1\" \"${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1" .xcdatamodeld`.momd\""
      xcrun momc "${PODS_ROOT}/$1" "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/`basename "$1" .xcdatamodeld`.momd"
      ;;
    *.xcassets)
      ;;
    /*)
      echo "$1"
      echo "$1" >> "$RESOURCES_TO_COPY"
      ;;
    *)
      echo "${PODS_ROOT}/$1"
      echo "${PODS_ROOT}/$1" >> "$RESOURCES_TO_COPY"
      ;;
  esac
}
          install_resource "DBCamera/DBCamera/Resources/DBCameraImages.xcassets"
                    install_resource "DBCamera/DBCamera/Localizations/en.lproj"
                    install_resource "DBCamera/DBCamera/Localizations/es.lproj"
                    install_resource "DBCamera/DBCamera/Localizations/it.lproj"
                    install_resource "DBCamera/DBCamera/Localizations/pt.lproj"
                    install_resource "DBCamera/DBCamera/Localizations/tr.lproj"
                    install_resource "DBCamera/DBCamera/Filters/1977.acv"
                    install_resource "DBCamera/DBCamera/Filters/amaro.acv"
                    install_resource "DBCamera/DBCamera/Filters/Hudson.acv"
                    install_resource "DBCamera/DBCamera/Filters/mayfair.acv"
                    install_resource "DBCamera/DBCamera/Filters/Nashville.acv"
                    install_resource "DBCamera/DBCamera/Filters/Valencia.acv"
                    install_resource "GPUImage/framework/Resources/lookup.png"
                    install_resource "GPUImage/framework/Resources/lookup_amatorka.png"
                    install_resource "GPUImage/framework/Resources/lookup_miss_etikate.png"
                    install_resource "GPUImage/framework/Resources/lookup_soft_elegance_1.png"
                    install_resource "GPUImage/framework/Resources/lookup_soft_elegance_2.png"
                    install_resource "STKWebKitViewController/Pod/Assets/back.png"
                    install_resource "STKWebKitViewController/Pod/Assets/back@2x.png"
                    install_resource "STKWebKitViewController/Pod/Assets/forward.png"
                    install_resource "STKWebKitViewController/Pod/Assets/forward@2x.png"
                    install_resource "STKWebKitViewController/Pod/Assets/refresh.png"
                    install_resource "STKWebKitViewController/Pod/Assets/refresh@2x.png"
                    install_resource "STKWebKitViewController/Pod/Assets/stop.png"
                    install_resource "STKWebKitViewController/Pod/Assets/stop@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundError.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundError@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundErrorIcon.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundErrorIcon@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundMessage.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundMessage@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundSuccess.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundSuccess@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundSuccessIcon.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundSuccessIcon@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundWarning.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundWarning@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundWarningIcon.png"
                    install_resource "TSMessages/Pod/Assets/NotificationBackgroundWarningIcon@2x.png"
                    install_resource "TSMessages/Pod/Assets/NotificationButtonBackground.png"
                    install_resource "TSMessages/Pod/Assets/NotificationButtonBackground@2x.png"
                    install_resource "TSMessages/Pod/Assets/TSMessagesDefaultDesign.json"
          
rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${CONFIGURATION_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
if [[ "${ACTION}" == "install" ]]; then
  rsync -avr --copy-links --no-relative --exclude '*/.svn/*' --files-from="$RESOURCES_TO_COPY" / "${INSTALL_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
fi
rm -f "$RESOURCES_TO_COPY"

if [[ -n "${WRAPPER_EXTENSION}" ]] && [ "`xcrun --find actool`" ] && [ `find . -name '*.xcassets' | wc -l` -ne 0 ]
then
  case "${TARGETED_DEVICE_FAMILY}" in
    1,2)
      TARGET_DEVICE_ARGS="--target-device ipad --target-device iphone"
      ;;
    1)
      TARGET_DEVICE_ARGS="--target-device iphone"
      ;;
    2)
      TARGET_DEVICE_ARGS="--target-device ipad"
      ;;
    *)
      TARGET_DEVICE_ARGS="--target-device mac"
      ;;
  esac
  find "${PWD}" -name "*.xcassets" -print0 | xargs -0 actool --output-format human-readable-text --notices --warnings --platform "${PLATFORM_NAME}" --minimum-deployment-target "${IPHONEOS_DEPLOYMENT_TARGET}" ${TARGET_DEVICE_ARGS} --compress-pngs --compile "${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
fi
