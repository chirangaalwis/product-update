#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#
# Copyright (c) 2019 WSO2 Inc. (http://www.wso2.org) All Rights Reserved.
#
# WSO2 Inc. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# ----------------------------------------------------------------------------

# Update the WSO2 product packs using WSO2 In-Place Client Tool

# TODO: Update the function comments
# TODO: Refine the code and review the variables and etc.

# capture the location of executables of command line utility tools used for the WSO2 product update process
readonly ECHO=`which echo`
readonly GREP=`which grep`
readonly JQ=`which jq`
readonly MAKE_DIR=`which mkdir`
readonly REMOVE=`which rm`
readonly TEE=`which tee`
readonly TEST=`which test`
readonly UNZIP=`which unzip`
readonly ZIP=`which zip`

# directory paths
readonly SCRIPT_HOME="`pwd`"
readonly BUILD_HOME="${HOME}/.wso2-build/products"
readonly IN_PLACE_BACKUP="${HOME}/.wso2-updates/backup"
readonly PRODUCT_POOL="${SCRIPT_HOME}/products"
# log file paths
readonly INFO_LOG_FILE="${SCRIPT_HOME}/update.log"
readonly STD_OUT_LOG_FILE="${SCRIPT_HOME}/stdout.log"

# read product profile details from JSON file
readonly PLATFORMS=$(<conf/data.json)
# email notification receivers
readonly RECEIVER=ie-group@wso2.com

# global variables
wso2_product_name=""
wso2_product_version=""
wso2_product=""
wum_channel=""
wso2_product_home=""

# check for WUM username
if [[ -z "${WUM_USER}" ]]; then
  log_error "Failed to initialize WSO2 Update Manager (WUM) client: Username environment variable (WUM_USER) not set. Exiting !"
fi

# check for WUM password
if [[ -z "${WUM_PASS}" ]]; then
  log_error "Failed to initialize WSO2 Update Manager (WUM) client: Password environment variable (WUM_PASS) not set. Exiting !"
fi

# logging functions
function log_error() {
  local string=$@
  ${ECHO} "[$(date +'%Y-%m-%dT%H:%M:%S%z')][ERROR]: ${string}" >&1 | ${TEE} -a ${INFO_LOG_FILE}
  ${ECHO} -e ${string} | ${MAIL} -s "WSO2 Product Update Failure" ${RECEIVER}
  exit 1
}

function log_info() {
  ${ECHO} "[$(date +'%Y-%m-%dT%H:%M:%S%z')][INFO]: $@" >&1 | ${TEE} -a ${INFO_LOG_FILE}
}

function log_warn() {
  ${ECHO} "[$(date +'%Y-%m-%dT%H:%M:%S%z')][WARN]: $@" >&1 | ${TEE} -a ${INFO_LOG_FILE}
}

#######################################
# Validate the WUM channel data input
# Globals:
#   wum_channel: Name of the WUM channel
# Arguments:
#   None
# Returns:
#   Erroneous exit code if the WUM channel name is empty or not among the recognized WUM channels
#######################################
function validate_wum_channel() {
  # check if the global variables are empty
  # check if the name of the WUM channel, is empty
  if [[ -z "${wum_channel}" ]]; then
    log_warn "Failed to validate the WUM channel: Name of the WUM channel is empty !"
    return 1
  fi

  # check if the WUM channel name is among the recognized WUM channels
  if [[ ! "${wum_channel}" =~ ^(full|security)$ ]]; then
    log_warn "Failed to validate the WUM channel: Invalid WUM channel !"
    return 1
  fi

  # if the WUM channel input validation has passed
  return 0
}

#######################################
# Add a WSO2 product if not added earlier
# Globals:
#   wso2_product: Name of the WSO2 product
# Arguments:
#   None
# Returns:
#   None
#######################################
function add_wso2_product() {
  if ! ${TEST} -f ${wso2_product_home}/${wso2_product}.zip; then
   log_info "${wso2_product}-${wum_channel} has not been added previously. Adding ${wso2_product} !."

   ${MAKE_DIR} -p ${wso2_product_home}

   # TODO: implement a mechanism to obtain the product pack from the hosted location (TBD)
   cp ~/.wum3/products/${wso2_product_name}/${wso2_product_version}/${wso2_product}.zip ${BUILD_HOME}/${wso2_product_name}/${wso2_product_version}/${wum_channel}

   ${UNZIP} ${wso2_product_home}/${wso2_product}.zip -d ${wso2_product_home}
  fi

  if ! ${TEST} -d ${wso2_product_home}/${wso2_product}; then
   log_info "${wso2_product}-${wum_channel} has not been unzipped. Unzipping ${wso2_product} product distribution !."

   ${UNZIP} ${wso2_product_home}/${wso2_product}.zip -d ${wso2_product_home}
  fi
}

#######################################
# Obtain the latest WSO2 updates for a WSO2 product
# Globals:
#   wso2_product: Name of the WSO2 product as per WUM
#   wum_channel: Name of the WUM channel
# Arguments:
#   None
# Returns:
#   None
#######################################
function get_wso2_updates() {
  log_info "Get WSO2 updates from ${wum_channel} WUM channel for ${wso2_product} !."

  # move to the parent directory containing the product pack
  pushd ${wso2_product_home}

  # execute the WSO2 in-place update tool
  ./${wso2_product}/bin/update_linux \
  --channel ${wum_channel} \
  --username ${WUM_USER} \
  --password ${WUM_PASS} \
  --verbose | ${TEE} -a ${STD_OUT_LOG_FILE}

  # extract the exit code of the update tool command
  local update_status=${PIPESTATUS[0]}

  # handle updates to in-place update tool
  if [[ ${update_status} -eq 2 ]]; then
      log_info "WSO2 In-Place Update tool has been updated. Running update again !."

       # execute the wso2 in-place update tool
      ./${wso2_product_home}/${wso2_product}/bin/update_linux \
      --channel ${wum_channel} \
      --username ${WUM_USER} \
      --password ${WUM_PASS} \
      --verbose | ${TEE} -a ${STD_OUT_LOG_FILE}

      # extract the exit code of the update tool command
      update_status=${PIPESTATUS[0]}
  fi

  if [[ ! ${update_status} -eq 0 ]]; then
    log_error "WUM update failed for ${wso2_product} via ${wum_channel} channel. Exiting !"
    exit 1
  else
    if ! ${REMOVE} ${wso2_product_home}/${wso2_product}.zip; then
      log_error "Failed to remove the base product pack zip ${wso2_product}. Exiting !"
      exit 1
    fi

    if ! ${ZIP} -r ${wso2_product_home}/${wso2_product}.zip ${wso2_product}; then
      log_error "Failed to zip ${wso2_product} updated via ${wum_channel} channel. Exiting !"
      exit 1
    fi
    log_info "${wso2_product} has been updated via ${wum_channel} channel !."
  fi
}

#######################################
# Copy the latest product pack corresponding to a particular WSO2 product to the product pack pool directory
# Globals:
#   wso2_product_profile_name: Name of the WSO2 product profile as per WUM
#   wso2_product_version: Version of the WSO2 product profile
#   wum_channel: Name of the WUM channel
#   wso2_product_packs: List of packs corresponding to a particular WSO2 product
# Arguments:
#   None
# Returns:
#   None
#######################################
function copy_pack_to_destination() {
  ! ${TEST} -d ${PRODUCT_POOL} && ${MAKE_DIR} -p ${PRODUCT_POOL}

  local copy=`which cp`
  if ! ${copy} ${wso2_product_home}/${wso2_product}.zip ${PRODUCT_POOL}; then
    log_warn "Failed to copy ${wso2_product} to destination directory ${PRODUCT_POOL}. Exiting !"
  fi

  log_info "${wso2_product} has been successfully copied to the destination directory ${PRODUCT_POOL} !."
}

#######################################
# Clean up the unnecessary product packs corresponding to a particular WSO2 product
# Rest of the product packs apart from the one packaging the latest WSO2 updates are deemed unnecessary
# Globals:
#   wso2_product_packs: List of packs corresponding to a particular WSO2 product
# Arguments:
#   None
# Returns:
#   None
#######################################
function clean_up() {
  # delete the temporary location at which the product update process was executed
  if ! ${REMOVE} -rf ${BUILD_HOME}/*; then
    log_error "Failed to remove the updated product packs. Exiting !"
    exit 1
  fi

  # delete the existing backup copies created during WSO2 In-Place tool executions
  if ! ${REMOVE} -rf ${IN_PLACE_BACKUP}/*; then
    log_error "Failed to remove the backup copies created during WSO2 In-Place tool executions. Exiting !"
    exit 1
  fi
}

function main() {
  # flow of execution
  log_info "User: \"$(whoami)\", Group: \"$(groups)\""

  # clean the existing product pack folder
  ${TEST} -d ${PRODUCT_POOL} && ${REMOVE} -r ${PRODUCT_POOL}/*

  # get the number of platforms
  local no_of_platforms=$(echo "${PLATFORMS}" | ${JQ} '.platforms | length')

  # loop through each platform
  for platform_index in $(seq 0 $((${no_of_platforms}-1))); do
    # capture the platform details
    local platform=$(echo "${PLATFORMS}" | ${JQ} -r --arg platform "${platform_index}" '.platforms[$platform|tonumber]')

    # get the number of products
    local no_of_products=$(echo "${platform}" | ${JQ} '.products | length')

    # loop through each product
    for product_index in $(seq 0 $((${no_of_products}-1))); do
      # capture the product details
      local product=$(echo "${platform}" | ${JQ} -r --arg product "${product_index}" '.products[$product|tonumber]')

      # name of the product
      wso2_product_name=$(echo "${product}" | ${JQ} -r '.name')

      # get the number of product versions
      local no_of_versions=$(echo "${product}" | ${JQ} '.versions | length')

      # loop through each product version
      for version_index in $(seq 0 $((${no_of_versions}-1))); do
        local version=$(echo "${product}" | ${JQ} -r --arg version "${version_index}" '.versions[$version|tonumber]')

        # product version for which the relevant WSO2 Updates need to be obtained
        wso2_product_version=$(echo "${version}" | ${JQ} -r '.product_version')

        # list of WUM channels for which the relevant WSO2 Updates need to be obtained
        # this value can be overridden for a relevant product version
        local wum_channels=$(echo "${PLATFORMS}" | ${JQ} '.wum_channels')

        # list of WUM channels for which the relevant WSO2 Updates need to be obtained
        local version_wum_channels=$(echo "${version}" | ${JQ} '.wum_channels')
        # override the WUM channels for a given product version
        [[ ! ${version_wum_channels} = null ]] && wum_channels=${version_wum_channels}

        wso2_product=${wso2_product_name}-${wso2_product_version}

        no_of_channels=$(echo "${wum_channels}" | ${JQ} '. | length')
        for channel_index in $(seq 0 $((${no_of_channels}-1))); do
          wum_channel=$(echo "${wum_channels}" | ${JQ} -r --arg channel "${channel_index}" '.[$channel|tonumber]')

          # validate the WUM channel input data
          if ! validate_wum_channel; then
            log_error "Failed to validate the WUM channel input. Exiting !"
          fi

          wso2_product_home="${BUILD_HOME}/${wso2_product_name}/${wso2_product_version}/${wum_channel}"

          add_wso2_product
          get_wso2_updates
          copy_pack_to_destination
          clean_up
        done
      done
    done
  done
}

main
