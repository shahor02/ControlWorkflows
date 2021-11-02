#!/usr/bin/env bash

# set -x;
set -e;
set -u;

source helpers.sh

WF_NAME=phos-raw-clusters-local
QC_GEN_CONFIG_PATH='json://'`pwd`'/etc/phos-raw-clusters-flpepn.json'
QC_FINAL_CONFIG_PATH='consul-json://{{ consul_endpoint }}/o2/components/qc/ANY/any/phos-raw-clusters-flpepn'
QC_CONFIG_PARAM='qc_config_uri'

cd ../

o2-dpl-raw-proxy -b --session default --dataspec 'x:PHS/RAWDATA;dd:FLP/DISTSUBTIMEFRAME/0' --readout-proxy '--channel-config "name=readout-proxy,type=pull,method=connect,address=ipc:///tmp/stf-builder-dpl-pipe-0,transport=shmem,rateLogging=1"' \
    | o2-phos-reco-workflow -b --input-type raw --output-type cells --session default --disable-root-output --pedestal off --keepHGLG off --pipeline 'PHOSRawToCellConverterSpec:3' \
    | o2-qc -b --config ${QC_GEN_CONFIG_PATH} --local --host flp \
    | o2-dpl-output-proxy -b --session default --dataspec 'x:PHS/RAWDATA;CEL:PHS/CELLS/0;CTR:PHS/CELLTRIGREC/0;dd:FLP/DISTSUBTIMEFRAME/0' --dpl-output-proxy '--channel-config "name=downstream,type=push,method=bind,address=ipc:///tmp/stf-pipe-0,rateLogging=1,transport=shmem"' --o2-control $WF_NAME

# add the templated QC config file path
ESCAPED_QC_FINAL_CONFIG_PATH=$(printf '%s\n' "$QC_FINAL_CONFIG_PATH" | sed -e 's/[\/&]/\\&/g')
sed -i /defaults:/\ a\\\ \\\ "${QC_CONFIG_PARAM}":\ \""${ESCAPED_QC_FINAL_CONFIG_PATH}"\" workflows/${WF_NAME}.yaml

# find and replace all usages of the QC config path which was used to generate the workflow
ESCAPED_QC_GEN_CONFIG_PATH=$(printf '%s\n' "$QC_GEN_CONFIG_PATH" | sed -e 's/[]\/$*.^[]/\\&/g');
sed -i "s/""${ESCAPED_QC_GEN_CONFIG_PATH}""/{{ ""${QC_CONFIG_PARAM}"" }}/g" workflows/${WF_NAME}.yaml tasks/${WF_NAME}-*

sed -i /defaults:/\ a\\\ \\\ "phos_keep_hglg: off" workflows/${WF_NAME}.yaml
sed -i /defaults:/\ a\\\ \\\ "phos_pedestal: off" workflows/${WF_NAME}.yaml

sed -i '/--pedestal/{n;s/.*/    - "{{ phos_pedestal }}"/}' tasks/${WF_NAME}-*
sed -i '/--keepHGLG/{n;s/.*/    - "{{ phos_keep_hglg }}"/}' tasks/${WF_NAME}-*


# QC_FINAL_CONFIG_PATH='consul-json://{{ consul_endpoint }}/o2/components/qc/ANY/any/its-qcmn-fhr-fee'
WF_NAME=phos-raw-clusters-remote

o2-qc --config $QC_GEN_CONFIG_PATH --remote -b --o2-control $WF_NAME

# add the templated QC config file path
ESCAPED_QC_FINAL_CONFIG_PATH=$(printf '%s\n' "$QC_FINAL_CONFIG_PATH" | sed -e 's/[\/&]/\\&/g')
sed -i /defaults:/\ a\\\ \\\ "${QC_CONFIG_PARAM}":\ \""${ESCAPED_QC_FINAL_CONFIG_PATH}"\" workflows/${WF_NAME}.yaml

# find and replace all usages of the QC config path which was used to generate the workflow
ESCAPED_QC_GEN_CONFIG_PATH=$(printf '%s\n' "$QC_GEN_CONFIG_PATH" | sed -e 's/[]\/$*.^[]/\\&/g');
sed -i "s/""${ESCAPED_QC_GEN_CONFIG_PATH}""/{{ ""${QC_CONFIG_PARAM}"" }}/g" workflows/${WF_NAME}.yaml tasks/${WF_NAME}-*

add_fmq_shmmonitor_role workflows/${WF_NAME}.yaml
add_qc_remote_machine_attribute workflows/${WF_NAME}.yaml alio2-cr1-qme06