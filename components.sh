#!/usr/bin/env bash

./adc.sh --function=create-catalog-template \
 --space-id="agent-space" \
  --catalog-id="default-catalog" \
  --catalog-template-id="agent-engine" \
  --display-name="Agent Engine" \
  --description="AI Reasoning Engine deployment that provisions networking, secure web proxy, network attachment, and Vertex AI Reasoning Engine for agent workloads."

./adc.sh --function=create-catalog-template-revision \
  --space-id="agent-space" \
  --catalog-id="default-catalog" \
  --catalog-template-id="agent-engine" \
  --revision-id="r1" \
  --ref-tag="v0.0.1" \
  --dir="modules/agent_engine" \
  --public-repo-url="bdpanigrahi-create/agent-engine" \
  --roles="roles/compute.networkAdmin,roles/resourcemanager.projectIamAdmin,roles/serviceusage.serviceUsageAdmin,roles/aiplatform.admin,roles/iam.serviceAccountAdmin,roles/iam.serviceAccountUser" \
  --terraform-version-constraint=">= 1.3" \
  --provider-versions='[{"source": "hashicorp/google", "version": ">= 6.6.0, < 8"}, {"source": "hashicorp/google-beta", "version": ">= 6.6.0, < 8"}]'

./adc.sh --function=create-catalog-template \
  --space-id="agent-space" \
  --catalog-id="default-catalog" \
  --catalog-template-id="compute-network-attachment" \
  --display-name="Compute Network Attachment" \
  --description="Compute Network Attachment module that provisions a Network Services Gateway and security policy for managed proxy workloads." \

./adc.sh --function=create-catalog-template-revision \
  --space-id="agent-space" \
  --catalog-id="default-catalog" \
  --catalog-template-id="compute-network-attachment" \
  --revision-id="r2" \
  --ref-tag="v0.0.1" \
  --dir="modules/network-attachment" \
  --public-repo-url="bdpanigrahi-create/agent-engine" \
  --roles="roles/compute.networkAdmin,roles/serviceusage.serviceUsageAdmin,roles/iam.serviceAccountAdmin,roles/iam.serviceAccountUser" \
  --terraform-version-constraint=">= 1.3" \
  --provider-versions='[{"source": "hashicorp/google", "version": ">= 6.6.0, < 8"}, {"source": "hashicorp/google-beta", "version": ">= 6.6.0, < 8"}]'