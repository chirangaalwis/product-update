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

# Setup the software required for updating WSO2 products

# external software to be installed
#   1. JQ - command-line JSON processor
#   2. WSO2 Update Manager (WUM) client

# capture the location of executables of command line utility tools used for the WSO2 product update process
readonly ECHO=`which echo`
readonly JQ=`which jq`
readonly REMOVE=`which rm`
readonly TAR=`which tar`
readonly TEE=`which tee`
readonly WGET=`which wget`
readonly WUM=`which wum`
# version of WSO2 Update Manager (WUM) to be installed
readonly WUM_VERSION=3.0.6
# log file name
readonly LOG_FILE="update.log"

# logging functions
function log_error() {
    ${ECHO} "[$(date +'%Y-%m-%dT%H:%M:%S%z')][ERROR][SETUP]: $@" >&1 | ${TEE} -a ${LOG_FILE}
    exit 1
}

function log_info() {
  ${ECHO} "[$(date +'%Y-%m-%dT%H:%M:%S%z')][INFO][SETUP]: $@" >&1 | ${TEE} -a ${LOG_FILE}
}

#######################################
# Install a specified Debian package via APT
# Globals:
#   None
# Arguments:
#   Name of the Debian package to install
# Returns:
#   None
#######################################
function install_package() {
  # check if the tag argument has been provided
  if [[ -z "${1}" ]]; then
    log_error "Failed to install the software package via APT: No package name specified. Exiting !"
  fi

  # update with the new list of software packages
  if ! apt-get update; then
    log_error "Failed to update with the new list of software packages via APT. Exiting !"
  fi
  # install the specified software package
  if ! apt-get install -y ${1}; then
    log_error "Failed to install the software package ${1}, via APT. Exiting !"
  fi

  log_info "Successfully installed the software package ${1}, via APT !!!"
}

if [[ ${UID} != 0 ]]; then
  log_info "Please run this script with sudo !!!"
  log_info "sudo $0 $*"
  exit 1
fi

# check the availability of command line utility tools used for the WSO2 product update process
# if not, install them
if [[ ! ${JQ} ]]; then
  log_info "Command-line JSON processor not installed !"
  log_info "Installing JQ - command-line JSON processor..."
  install_package jq
fi

if [[ ! ${WUM} ]]; then
  log_info "WSO2 Update Manager (WUM) client not installed !"
  log_info "Installing WUM client..."

  wum_distribution="wum-${WUM_VERSION}-linux-x64.tar.gz"
  download_url="http://product-dist.wso2.com/downloads/wum/${WUM_VERSION}/${wum_distribution}"
  # download the WUM client distribution
  if ! ${WGET} ${download_url}; then
    log_error "Failed to download the WSO2 Update Manager (WUM) client distribution. Exiting !"
  fi
  # extract the WUM client distribution
  if ! ${TAR} -C /usr/local -xzf ${wum_distribution}; then
    log_error "Failed to extract the WSO2 Update Manager (WUM) client distribution. Exiting !"
  fi

  # clean up the downloaded WUM distribution
  ${REMOVE} -f ${wum_distribution}

  log_info "Successfully obtained the WUM client distribution !!!"
fi

log_info "Successfully installed the software dependencies required for the WSO2 product update process !!!"
