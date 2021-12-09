#!/bin/bash

# ************************************************************** 
# * - DESCRIPCION: Shell principal para la instalación de CP4I *
# * - EJECUCION:   SHELL    								   	 							 *
# * - AUTOR:       Guerra Arnaiz, Cesar Ricardo  		  	 			 *
# * - FECHA:       10/12/2021			      										   *
# * - VERSION:     1.0									   	    							 *
# ************************************************************** 

clear

vPATH=$(pwd)
. ${vPATH}/properties/CP4I.properties
set -a; . "${vPATH}/properties/CP4I.properties";
 
vCURRENT_DATE=`DATE +%Y%m%d%H%M%S`
vTRANSACTION="$vCURRENT_DATE - [INFO]": 
vWAIT_TIME=5
vDATE_LOG=`date +%Y%m%d`
vLOG_FILE='cp4i_'${vDATE_LOG}
vLOG_PATH=${vPATH}'/log/'${vLOG_FILE}'.log' 
vLOG_PATH_TEMP=${vPATH}'/log/'${vLOG_FILE}'.temp'

echo "${vTRANSACTION} ******************** [START] ********************"
echo "${vTRANSACTION} EXECUTING SCRIPTs [YAMLs]..."
 
############## VALIDACIONES DE 'OC' ##############
if ! command -v oc &> /dev/null; then
    echo "${vTRANSACTION} oc could not be found." && echo "Please install from here: [https://docs.openshift.com/container-platform/4.9/cli_reference/openshift_cli/getting-started-cli.html]"
    exit
fi

isloggedIn=`oc whoami &> /dev/null`
if [ $? -ne 0 ]; then
    echo "${vTRANSACTION} oc is not logged in" && echo "Please you need to do login: [https://docs.openshift.com/container-platform/4.9/cli_reference/openshift_cli/getting-started-cli.html#cli-logging-in_cli-developer-commands]"
    exit
fi

############## VALIDATIONS ABOUT: [NAMESPACE] ##############  
echo "${vTRANSACTION}> [ STEP 1 OF 6 ]: Creating the 'new Project/Namespace': [${namespace_name}]..${CLEAR}"
cat ${vPATH}/scripts/1_new-project.yml | sed "s/NAMESPACE_NAME/${namespace_name}/" > ${vLOG_PATH_TEMP}
oc apply -f ${vLOG_PATH_TEMP} &> /dev/null  && sleep 30
cat ${vLOG_PATH_TEMP} >> ${vLOG_PATH}
rm -f ${vLOG_PATH_TEMP}
echo "${vTRANSACTION}>> Done .."

############## VALIDATIONS ABOUT: [CATALOGs] ##############  
echo "${vTRANSACTION}> [ STEP 2 OF 6 ]: Adding a IBM 'Operator Catalog'..${CLEAR}"
cat ${vPATH}/scripts/2_ibm-operator-catalog.yml | sed "s/NAMESPACE_NAME/${namespace_name}/" > ${vLOG_PATH_TEMP}
oc apply -f ${vLOG_PATH_TEMP} &> /dev/null  && sleep 30
cat ${vLOG_PATH_TEMP} >> ${vLOG_PATH}
rm -f ${vLOG_PATH_TEMP}
echo "${vTRANSACTION}>> Done .."


############## VALIDATIONS ABOUT: [SECRET] ############## 
echo "${vTRANSACTION}> [ STEP 3 OF 6 ]: Adding a 'ImagePull Secret'..${CLEAR}"
cat ${vPATH}/scripts/3_secret_entitlement-key.oc | sed "s/NAMESPACE_NAME/${namespace_name}/" | sed "s/ENTITLEMENT_KEY_TOKEN/${entitlement_key_token}/" > $vLOG_PATH_TEMP
oc apply secret ${vLOG_PATH_TEMP} &> /dev/null && sleep 30	
cat ${vLOG_PATH_TEMP} >> ${vLOG_PATH}
rm -f ${vLOG_PATH_TEMP}
echo "${vTRANSACTION}>> Done .."


############## VALIDATIONS ABOUT: [OPERATORs] ############## 
echo "${vTRANSACTION}> [ STEP 4 OF 6 ]: Creating a 'IBM CP4I' Subscriptions..${CLEAR}"
cat ${vPATH}/scripts/4_operator-group.yml | sed "s/NAMESPACE_NAME/${namespace_name}/" > ${vLOG_PATH_TEMP}
oc apply -f ${vLOG_PATH_TEMP} &> /dev/null && sleep 30		
cat ${vLOG_PATH_TEMP} >> ${vLOG_PATH}
rm -f ${vLOG_PATH_TEMP}

cat ${vPATH}/scripts/5_operator-subscription.yml | sed "s/NAMESPACE_NAME/${namespace_name}/" | sed "s/STARTING_CSV/${starting_csv}/" | sed "s/CHANNEL_VERSION/${channel_version}/" | sed "s/OPERATOR_NAME/${operator_name}/" > ${vLOG_PATH_TEMP}
oc apply -f ${vLOG_PATH_TEMP} &> /dev/null && sleep 300	
cat ${vLOG_PATH_TEMP} >> ${vLOG_PATH}
rm -f ${vLOG_PATH_TEMP}

while [[ $(oc get pods -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}' -n ${namespace_name}) == "False" ]]; do echo ">>> waiting for the PODs change to be READY" && sleep 30; done
echo "${vTRANSACTION}>> Done .."


############## VALIDATIONS ABOUT: [PLATFORM-NAVIGATOR] ############## 
echo "${vTRANSACTION}> [ STEP 5 OF 6 ]: Deploying a Instance of 'Platform-Navigator' (it will take around: 45 min)..${CLEAR}"
cat ${vPATH}/scripts/6_platform-navigator.yml | sed "s/NAMESPACE_NAME/${namespace_name}/" | sed "s/PLATFORM_NAVIGATOR_NAME/${platform_navigator_name}/" | sed "s/PLATFORM_NAVIGATOR_VERSION/${platform_navigator_version}/" | sed "s/PLATFORM_NAVIGATOR_LICENSE/${platform_navigator_license}/" | sed "s/PLATFORM_NAVIGATOR_STORAGE/${platform_navigator_storage}/" | sed "s/PLATFORM_NAVIGATOR_REPLICAS/${platform_navigator_replicas}/" > ${vLOG_PATH_TEMP}
	
oc apply -f ${vLOG_PATH_TEMP} &> /dev/null && sleep 100	
cat ${vLOG_PATH_TEMP} >> ${vLOG_PATH}
rm -f ${vLOG_PATH_TEMP}

while [[ $(oc get PlatformNavigator/pn-cloudpak-instance -n ${namespace_name} -o 'jsonpath={..status.conditions[].type}') != "Ready" ]]; do echo "${vTRANSACTION}>>> waiting for 'Platform-Navigator' change to be READY" && sleep 300; done
echo "${vTRANSACTION}>> Done .."


############## VALIDATIONS ABOUT: [ACCESS TO CREDENTIALs] ############## 
echo "${vTRANSACTION}> [ STEP 6 OF 6 ]: 'Platform-Navigator' access credentials.." && echo "# console_url";
oc get PlatformNavigator ${platform_navigator_name} -o jsonpath='{.status.endpoints[].uri}' -n ${namespace_name}; echo "" 
oc extract secret/platform-auth-idp-credentials -n ibm-common-services --to=-  
echo "${vTRANSACTION}>> Done .."

echo "${vTRANSACTION} Generating execution 'LOG-FILE' in the PATH:[${vLOG_PATH}]..." 
echo "${vTRANSACTION} ********************** [END] *********************"
echo "${vTRANSACTION} Waiting: [${vWAIT_TIME}] seconds to close..."
sleep ${vWAIT_TIME}

exit

