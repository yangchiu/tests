*** Settings ***
Documentation    VM VLAN Negative Test Cases
...    Port of harvester/tests apis/test_3_vm_functions.py test_vm_with_bogus_vlan.
...    A VM attached to a VLAN network with no DHCP must come up Running with
...    a second interface that has a MAC address but no IP address assigned.
Test Tags        regression    virtualmachines    negative

Resource         ../../../keywords/variables.resource
Resource         ../../../keywords/common.resource
Resource         ../../../keywords/image.resource
Resource         ../../../keywords/network.resource
Resource         ../../../keywords/virtualmachine.resource

Suite Setup       Local Suite Setup
Test Teardown     Common Test Teardown
Suite Teardown    Local Suite Teardown


*** Variables ***
${VLAN_INTERFACE_NAME}    no-dhcp
# Dynamic Variables
${IMAGE_NAME}              ${EMPTY}
${VM_NAME}                 ${EMPTY}
${CLUSTER_NETWORK_NAME}    ${EMPTY}
${VLAN_CONFIG_NAME}        ${EMPTY}
${VLAN_NETWORK_NAME}       ${EMPTY}
${BOGUS_VLAN_ID}           ${EMPTY}


*** Test Cases ***
VM With Bogus VLAN Gets No IP Address
    [Tags]    p0    sanity
    [Documentation]    Build a VM with a second (VLAN) network interface that
    ...    has no DHCP server behind it, and verify:
    ...    - the VM still comes up Running
    ...    - the extra interface shows up with a MAC address
    ...    - the extra interface has NO IP address assigned
    ...    - the VM (and its volumes) can be deleted afterwards
    ${networks}=    Create List
    ...    ${{ {'name': '${VLAN_INTERFACE_NAME}', 'network_name': '${DEFAULT_NAMESPACE}/${VLAN_NETWORK_NAME}'} }}
    Given VM is created    ${VM_NAME}    ${IMAGE_NAME}    networks=${networks}
    When VM should be running    ${VM_NAME}
    Then VM Interface Should Have No IP Address    ${VM_NAME}    ${VLAN_INTERFACE_NAME}
    When VM is deleted    ${VM_NAME}
    Then VM should be deleted    ${VM_NAME}


*** Keywords ***
Local Suite Setup
    ${suffix}=    Generate Unique Name
    ${suffix_short}=    Generate Unique Name    precise=${FALSE}
    Set Suite Variable    ${IMAGE_NAME}              image-${suffix}
    Set Suite Variable    ${VM_NAME}                 vm-vlan-${suffix}
    Set Suite Variable    ${CLUSTER_NETWORK_NAME}     cnet-${suffix_short}
    Set Suite Variable    ${VLAN_CONFIG_NAME}         vcfg-${suffix_short}
    Set up test environment
    Image is available for VM creation    ${IMAGE_NAME}    ${OPENSUSE_IMAGE_URL}

    # Build a cluster network + VLAN config (binds a NIC to it), then pick a
    # VLAN ID that isn't backed by any existing (DHCP-enabled) VLAN network,
    # so the VM's second interface never gets an IP address.
    network.Create Cluster Network    ${CLUSTER_NETWORK_NAME}
    network.Create VLAN Config    ${VLAN_CONFIG_NAME}    ${CLUSTER_NETWORK_NAME}    ${VLAN_NIC}
    network.Wait For Cluster Network Ready    ${CLUSTER_NETWORK_NAME}
    ${bogus_vlan_id}=    network.Get Available VLAN ID    ${VLAN_ID}
    Set Suite Variable    ${BOGUS_VLAN_ID}    ${bogus_vlan_id}
    Set Suite Variable    ${VLAN_NETWORK_NAME}    bogus-net-${bogus_vlan_id}
    network.Create VLAN Network    ${VLAN_NETWORK_NAME}    ${BOGUS_VLAN_ID}    ${CLUSTER_NETWORK_NAME}

Local Suite Teardown
    Run Keyword If All Tests Passed    Delete Suite Resources
    Run Keyword If Any Tests Failed    Log Variables

Delete Suite Resources
    Run Keyword And Ignore Error    VM is deleted    ${VM_NAME}
    Run Keyword And Ignore Error    network.Delete VLAN Network    ${VLAN_NETWORK_NAME}
    Run Keyword And Ignore Error    network.Delete VLAN Config    ${VLAN_CONFIG_NAME}
    Run Keyword And Ignore Error    network.Delete Cluster Network    ${CLUSTER_NETWORK_NAME}
    Run Keyword And Ignore Error    Delete image by name    ${IMAGE_NAME}


