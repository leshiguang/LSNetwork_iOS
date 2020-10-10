#!/bin/sh
# 不支持模拟器、bitCode的打包
#/bin/sh /${PROJECT_DIR}/ios-build-framework-non-simulator-script.sh

# 支持所有架构的打包
/bin/sh /${PROJECT_DIR}/ios-build-framework-script.sh

# 支持bitcode 但不支持模拟器的打包
#/bin/sh /${PROJECT_DIR}/ios-build-framework-non-simulator-support-bitcode-script.sh

