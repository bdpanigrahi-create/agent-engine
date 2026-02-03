#!/usr/bin/env bash
#
# This script is a command-line interface for managing catalog API calls.
#
# Dependencies:
#   This script requires 'gcloud' for authentication and 'jq' for JSON processing.
#
# Usage:
#   ./adc.sh --function=<function_name> [options]
#
# Functions:
#   create-space: Creates a new catalog space.
#   list-spaces: Lists all spaces in the catalog.
#   create-catalog-template: Creates a new catalog template.
#   list-catalog-templates: Lists all templates within a catalog.
#   delete-catalog-template: Deletes a specific catalog template.
#   create-catalog-template-revision: Creates a new revision for a catalog template.
#   list-catalog-template-revisions: Lists all revisions for a specific template.
#   delete-catalog-template-revision: Deletes a specific template revision.
#   create-share: Creates a new share to a destination space.
#   list-shared-templates: Lists all templates shared with a space.
#   query-lro: Queries a long-running operation (LRO).
#
# Example:
#   ./adc.sh --function=create-space --space-id="my-new-space-123" --enable-shared-templates
#   ./adc.sh --function=list-spaces
#   ./adc.sh --function=create-catalog-template \
#       --space-id="personal-space" --catalog-id="default-catalog" \
#       --catalog-template-id="cs-project-factory" \
#       --display-name="CS Project Factory" \
#       --description="This component creates the project factory output."
#   ./adc.sh --function=list-catalog-templates \
#       --space-id="personal-space" --catalog-id="default-catalog"
#   ./adc.sh --function=delete-catalog-template \
#       --space-id="personal-space" --catalog-id="default-catalog" \
#       --catalog-template-id="cloud-run"
#   ./adc.sh --function=create-catalog-template-revision \
#       --space-id="personal-space" --catalog-id="default-catalog" \
#       --catalog-template-id="cs-project-factory" --revision-id="r1" \
#       --repo-uri="projects/google-mpf-684874852204/locations/us-central1/connections/cmeesala-private-connection/gitRepositoryLinks/cmeesala-terraform-google-schwab-cloud-operations" \
#       --dir="modules/project-factory" \
#       --branch="main" \
#       --roles="roles/iam.serviceAccountUser,roles/iap.admin" \
#       --provider-versions='[{"source": "hashicorp/google", "version": ">= 6, < 7"}]' \
#       --terraform-version-constraint=">= 1.3"
#   ./adc.sh --function=list-catalog-template-revisions \
#       --space-id="personal-space" --catalog-id="default-catalog" \
#       --catalog-template-id="cs-project-factory"
#   ./adc.sh --function=delete-catalog-template-revision \
#       --space-id="personal-space" --catalog-id="default-catalog" \
#       --catalog-template-id="cs-project-factory" --revision-id="r1"
#   ./adc.sh --function=create-share \
#       --space-id="personal-space" --catalog-id="default-catalog" \
#       --share-id="personal-space-share" --destination-space-id="another-space"
#   ./adc.sh --function=list-shared-templates \
#       --space-id="personal-space"
#   ./adc.sh --function=query-lro --operation-name="operation-1756109624817-63d2c225fb6dd-64d2c1f3-67ee7aef"

# --- Global Variables ---
# These variables should be configured for your environment.
HOST="designcenter.googleapis.com"
LOCATION_ID="us-central1"
PROJECT_ID="google-mpf-ksbto0dspv4n"

# --- Helper Functions ---

# Function to print a usage message and exit.
usage() {
    echo "Usage: $0 --function=<function_name> [options]"
    echo "For help with a specific function, run: $0 --function=<function_name> --help"
    exit 1
}

# Function to poll a long-running operation until it is done, or an error occurs.
# Parameters:
#   $1: The full operation name (e.g., projects/.../operations/...).
#   $2: The verbose flag ("true" or "false").
_poll-lro() {
    local operation_name="$1"
    local verbose="$2"
    local retries=0
    local max_retries="20"
    local poll_interval="3"

    echo "--- Polling LRO: ${operation_name} ---"

    while [[ "$retries" -lt "$max_retries" ]]; do
        # Use a simplified query-lro logic to get the status without printing full output on every poll
        local TOKEN=$(gcloud auth print-access-token)
        local query_url="https://${HOST}/v1alpha/${operation_name}"
        
        if [[ "$verbose" == "true" ]]; then
            echo "Attempt $((retries + 1))/${max_retries}: Querying LRO status at ${query_url}..."
        fi
        
        local lro_response=$(curl -s -X GET -H "Authorization: Bearer ${TOKEN}" "${query_url}")
        local is_done=$(echo "$lro_response" | jq -r '.done')
        
        if [[ "$is_done" == "true" ]]; then
            local error_check=$(echo "$lro_response" | jq -r '.error')
            if [[ "$error_check" != "null" ]]; then
                echo "❌ LRO failed after $((retries + 1)) attempts. Error details:"
                echo "$lro_response" | jq '.'
                return 1
            else
                echo "✅ LRO completed successfully after $((retries + 1)) attempts."
                # Print the final response
                echo "$lro_response" | jq '.response'
                return 0
            fi
        fi

        echo "Still running... waiting ${poll_interval} seconds (Attempt $((retries + 1))/${max_retries})"
        sleep "$poll_interval"
        retries=$((retries + 1))
    done

    echo "❌ LRO polling timed out after ${max_retries} attempts (${poll_interval}s interval)."
    return 1
}

# --- API Functions ---

# Function to create a new space.
# Parameters:
#   --space-id <string>: The ID for the new space.
#   --enable-shared-templates: To flag whether to have Google Opinionated components as part of this space.
create-space() {
    local space_id=""
    local enableSharedTemplates="false"
    local verbose="false"
    
    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --enable-shared-templates)
                enableSharedTemplates="true"
                shift 1
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=create-space [--space-id=<string> | --space-id=<env:SPACE_ID>] [--enable-shared-templates] [-v|--verbose]"
                echo ""
                echo "Creates a new space in the catalog."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space to create. Falls back to the SPACE_ID environment variable if not provided."
                echo "  --enable-shared-templates: Flag to enable Google Opinionated components."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'create-space'."
                return 1
                ;;
        esac
    done
    
    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)
    
    # Construct the JSON payload
    PAYLOAD='{"enableGcpSharedTemplates": '"${enableSharedTemplates}"'}'

    # Construct the curl command
    local curl_command="curl -X POST -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" -d '${PAYLOAD}' \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces?space_id=${space_id}\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to list all spaces.
# Parameters:
#   None
list-spaces() {
    local verbose="false"
    
    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=list-spaces [-v|--verbose]"
                echo ""
                echo "Lists all available spaces in the catalog for the configured project and location."
                echo ""
                echo "Optional parameters:"
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'list-spaces'."
                return 1
                ;;
        esac
    done

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the curl command
    local curl_command="curl -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to create a new catalog template.
# Parameters:
#   --space-id <string>: The ID of the space to create the template in.
#   --catalog-id <string>: The ID of the catalog to create the template in.
#   --catalog-template-id <string>: The ID of the catalog template to create.
#   --display-name <string>: The display name of the template.
#   --description <string>: A description of the template.
create-catalog-template() {
    local space_id=""
    local catalog_id=""
    local catalog_template_id=""
    local display_name=""
    local description=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --catalog-id=*)
                catalog_id="${1#*=}"
                shift
                ;;
            --catalog-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-id requires an argument."; return 1; fi
                catalog_id="$2"
                shift 2
                ;;
            --catalog-template-id=*)
                catalog_template_id="${1#*=}"
                shift
                ;;
            --catalog-template-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-template-id requires an argument."; return 1; fi
                catalog_template_id="$2"
                shift 2
                ;;
            --display-name=*)
                display_name="${1#*=}"
                shift
                ;;
            --display-name)
                if [[ -z "$2" ]]; then echo "Error: --display-name requires an argument."; return 1; fi
                display_name="$2"
                shift 2
                ;;
            --description=*)
                description="${1#*=}"
                shift
                ;;
            --description)
                if [[ -z "$2" ]]; then echo "Error: --description requires an argument."; return 1; fi
                description="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=create-catalog-template [--space-id=<string>] [--catalog-id=<string>] --catalog-template-id=<string> --display-name=<string> --description=<string> [-v|--verbose]"
                echo ""
                echo "Creates a new catalog template with the specified details."
                echo ""
                echo "Required parameters:"
                echo "  --catalog-template-id: The ID for the new template."
                echo "  --display-name: The display name for the template."
                echo "  --description: The description for the template."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  --catalog-id: The ID of the catalog. Falls back to the CATALOG_ID environment variable."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'create-catalog-template'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Check for catalog_id, falling back to environment variable
    if [[ -z "$catalog_id" ]]; then
        if [[ -z "$CATALOG_ID" ]]; then
            echo "Error: Required parameter --catalog-id is missing. Please provide it as a command-line argument or set the CATALOG_ID environment variable."
            return 1
        fi
        catalog_id="$CATALOG_ID"
    fi

    # Validate remaining required parameters
    if [[ -z "$catalog_template_id" || -z "$display_name" || -z "$description" ]]; then
        echo "Error: All required parameters (--catalog-template-id, --display-name, --description) must be provided."
        return 1
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the JSON payload
    PAYLOAD=$(jq -n --arg dn "$display_name" --arg desc "$description" \
              '{displayName: $dn, description: $desc, templateCategory: "COMPONENT_TEMPLATE"}')

    # Construct the curl command
    local curl_command="curl -X POST -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" -d '${PAYLOAD}' \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/templates?catalog_template_id=${catalog_template_id}\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to list all catalog templates within a specified catalog.
# Parameters:
#   --space-id <string>: The ID of the space containing the catalog.
#   --catalog-id <string>: The ID of the catalog containing the templates.
list-catalog-templates() {
    local space_id=""
    local catalog_id=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --catalog-id=*)
                catalog_id="${1#*=}"
                shift
                ;;
            --catalog-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-id requires an argument."; return 1; fi
                catalog_id="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=list-catalog-templates [--space-id=<string>] [--catalog-id=<string>] [-v|--verbose]"
                echo ""
                echo "Lists all available templates within a specified catalog."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  --catalog-id: The ID of the catalog. Falls back to the CATALOG_ID environment variable."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'list-catalog-templates'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Check for catalog_id, falling back to environment variable
    if [[ -z "$catalog_id" ]]; then
        if [[ -z "$CATALOG_ID" ]]; then
            echo "Error: Required parameter --catalog-id is missing. Please provide it as a command-line argument or set the CATALOG_ID environment variable."
            return 1
        fi
        catalog_id="$CATALOG_ID"
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the curl command
    local curl_command="curl -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/templates\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to delete a specific catalog template.
# Parameters:
#   --space-id <string>: The ID of the space containing the catalog.
#   --catalog-id <string>: The ID of the catalog containing the template.
#   --catalog-template-id <string>: The ID of the template to delete.
delete-catalog-template() {
    local space_id=""
    local catalog_id=""
    local catalog_template_id=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --catalog-id=*)
                catalog_id="${1#*=}"
                shift
                ;;
            --catalog-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-id requires an argument."; return 1; fi
                catalog_id="$2"
                shift 2
                ;;
            --catalog-template-id=*)
                catalog_template_id="${1#*=}"
                shift
                ;;
            --catalog-template-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-template-id requires an argument."; return 1; fi
                catalog_template_id="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=delete-catalog-template [--space-id=<string>] [--catalog-id=<string>] --catalog-template-id=<string> [-v|--verbose]"
                echo ""
                echo "Deletes a specific catalog template."
                echo ""
                echo "Required parameters:"
                echo "  --catalog-template-id: The ID of the template to delete."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  --catalog-id: The ID of the catalog. Falls back to the CATALOG_ID environment variable."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'delete-catalog-template'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Check for catalog_id, falling back to environment variable
    if [[ -z "$catalog_id" ]]; then
        if [[ -z "$CATALOG_ID" ]]; then
            echo "Error: Required parameter --catalog-id is missing. Please provide it as a command-line argument or set the CATALOG_ID environment variable."
            return 1
        fi
        catalog_id="$CATALOG_ID"
    fi

    # Validate remaining required parameters
    if [[ -z "$catalog_template_id" ]]; then
        echo "Error: Required parameter --catalog-template-id is missing."
        return 1
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the curl command
    local curl_command="curl -X DELETE -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" -d '{}' \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/templates/${catalog_template_id}\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to create a new revision for a catalog template.
# Parameters:
#   --space-id <string>: The ID of the space.
#   --catalog-id <string>: The ID of the catalog.
#   --catalog-template-id <string>: The ID of the template to create a revision for.
#   --revision-id <string>: The ID for the new revision.
#   --repo-uri <string>: (Mutually exclusive with --public-repo-url) The URI of the Developer Connect Git repository link.
#   --public-repo-url <string>: (Mutually exclusive with --repo-uri) The URL of a public Git repository.
#   --dir <string>: The directory within the Git repository.
#   --branch <string>: (Mutually exclusive with --ref-tag and --commit-sha) The Git branch to reference (for --repo-uri).
#   --ref-tag <string>: (Mutually exclusive with --branch and --commit-sha) The Git tag to reference.
#   --commit-sha <string>: (Mutually exclusive with --branch and --ref-tag) The Git commit SHA to reference (for --repo-uri).
#   --roles <string>: A comma-separated list of IAM roles.
#   --provider-versions <json_string>: A JSON array string of provider versions.
#   --terraform-version-constraint <string>: The Terraform version constraint.
create-catalog-template-revision() {
    local space_id=""
    local catalog_id=""
    local catalog_template_id=""
    local revision_id=""
    local repo_uri=""
    local public_repo_url=""
    local dir=""
    local branch=""
    local ref_tag=""
    local commit_sha=""
    local roles=""
    local verbose="false"
    local wait_for_lro="true"
    # Default values for optional parameters
    local provider_versions='[{"source": "hashicorp/google", "version": ">= 6, < 7"}]'
    local terraform_version_constraint=">= 1.3"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --catalog-id=*)
                catalog_id="${1#*=}"
                shift
                ;;
            --catalog-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-id requires an argument."; return 1; fi
                catalog_id="$2"
                shift 2
                ;;
            --catalog-template-id=*)
                catalog_template_id="${1#*=}"
                shift
                ;;
            --catalog-template-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-template-id requires an argument."; return 1; fi
                catalog_template_id="$2"
                shift 2
                ;;
            --revision-id=*)
                revision_id="${1#*=}"
                shift
                ;;
            --revision-id)
                if [[ -z "$2" ]]; then echo "Error: --revision-id requires an argument."; return 1; fi
                revision_id="$2"
                shift 2
                ;;
            --repo-uri=*)
                repo_uri="${1#*=}"
                shift
                ;;
            --repo-uri)
                if [[ -z "$2" ]]; then echo "Error: --repo-uri requires an argument."; return 1; fi
                repo_uri="$2"
                shift 2
                ;;
            --public-repo-url=*)
                public_repo_url="${1#*=}"
                shift
                ;;
            --public-repo-url)
                if [[ -z "$2" ]]; then echo "Error: --public-repo-url requires an argument."; return 1; fi
                public_repo_url="$2"
                shift 2
                ;;
            --dir=*)
                dir="${1#*=}"
                shift
                ;;
            --dir)
                if [[ -z "$2" ]]; then echo "Error: --dir requires an argument."; return 1; fi
                dir="$2"
                shift 2
                ;;
            --branch=*)
                branch="${1#*=}"
                shift
                ;;
            --branch)
                if [[ -z "$2" ]]; then echo "Error: --branch requires an argument."; return 1; fi
                branch="$2"
                shift 2
                ;;
            --ref-tag=*)
                ref_tag="${1#*=}"
                shift
                ;;
            --ref-tag)
                if [[ -z "$2" ]]; then echo "Error: --ref-tag requires an argument."; return 1; fi
                ref_tag="$2"
                shift 2
                ;;
            --commit-sha=*)
                commit_sha="${1#*=}"
                shift
                ;;
            --commit-sha)
                if [[ -z "$2" ]]; then echo "Error: --commit-sha requires an argument."; return 1; fi
                commit_sha="$2"
                shift 2
                ;;
            --roles=*)
                roles="${1#*=}"
                shift
                ;;
            --roles)
                if [[ -z "$2" ]]; then echo "Error: --roles requires an argument."; return 1; fi
                roles="$2"
                shift 2
                ;;
            --provider-versions=*)
                provider_versions="${1#*=}"
                shift
                ;;
            --provider-versions)
                if [[ -z "$2" ]]; then echo "Error: --provider-versions requires an argument."; return 1; fi
                provider_versions="$2"
                shift 2
                ;;
            --terraform-version-constraint=*)
                terraform_version_constraint="${1#*=}"
                shift
                ;;
            --terraform-version-constraint)
                if [[ -z "$2" ]]; then echo "Error: --terraform-version-constraint requires an argument."; return 1; fi
                terraform_version_constraint="$2"
                shift 2
                ;;
            --wait)
                wait_for_lro="true"
                shift 1
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=create-catalog-template-revision [--space-id=<string>] [--catalog-id=<string>] --catalog-template-id=<string> --revision-id=<string> (--repo-uri=<string> | --public-repo-url=<string>) [--dir=<string>] [--branch=<string>|--ref-tag=<string>|--commit-sha=<string>] --roles=<string> [--provider-versions=<json_string>] [--terraform-version-constraint=<string>] [-v|--verbose]"
                echo ""
                echo "Creates a new revision for a catalog template."
                echo ""
                echo "Required parameters:"
                echo "  --catalog-template-id: The ID of the template."
                echo "  --revision-id: The ID for the new revision."
                echo "  --roles: A comma-separated list of IAM roles. E.g., \"roles/iam.serviceAccountUser,roles/iap.admin\""
                echo ""
                echo "Mutually exclusive source parameters (one required):"
                echo "  --repo-uri: The URI of the Developer Connect repository link (for private repositories)."
                echo "  --public-repo-url: The URL of a public Git repository."
                echo ""
                echo "Reference parameters:"
                echo "  For --repo-uri, exactly one of --branch, --ref-tag, or --commit-sha is required."
                echo "  For --public-repo-url, --ref-tag is required."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  --catalog-id: The ID of the catalog. Falls back to the CATALOG_ID environment variable."
                echo "  --dir: The directory within the repository where the template is located."
                echo "  --provider-versions: A JSON array string of provider versions. Defaults to '[{\"source\": \"hashicorp/google\", \"version\": \">= 6, < 7\"}]'."
                echo "  --terraform-version-constraint: The Terraform version constraint. Defaults to \">= 1.3\"."
                echo "  --wait: Wait for the Long-Running Operation (LRO) to complete before exiting."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'create-catalog-template-revision'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Check for catalog_id, falling back to environment variable
    if [[ -z "$catalog_id" ]]; then
        if [[ -z "$CATALOG_ID" ]]; then
            echo "Error: Required parameter --catalog-id is missing. Please provide it as a command-line argument or set the CATALOG_ID environment variable."
            return 1
        fi
        catalog_id="$CATALOG_ID"
    fi
    
    # Validate remaining required parameters
    if [[ -z "$catalog_template_id" || -z "$revision_id" ]]; then
        echo "Error: All required parameters (--catalog-template-id, --revision-id) must be provided."
        return 1
    fi

    # Check for mutual exclusivity of source arguments
    if [[ -n "$repo_uri" && -n "$public_repo_url" ]]; then
        echo "Error: The arguments --repo-uri and --public-repo-url are mutually exclusive. Please provide only one."
        return 1
    fi

    if [[ -z "$repo_uri" && -z "$public_repo_url" ]]; then
        echo "Error: One of the source arguments (--repo-uri or --public-repo-url) must be provided."
        return 1
    fi
    
    local source_payload=""
    # Build the payload based on the source type
    if [[ -n "$repo_uri" ]]; then
        # Validate mutually exclusive reference parameters for repo-uri
        local ref_count=0
        if [[ -n "$branch" ]]; then ((ref_count++)); fi
        if [[ -n "$ref_tag" ]]; then ((ref_count++)); fi
        if [[ -n "$commit_sha" ]]; then ((ref_count++)); fi
        
        if [[ "$ref_count" -ne 1 ]]; then
            echo "Error: For --repo-uri, exactly one of --branch, --ref-tag, or --commit-sha must be provided."
            return 1
        fi
        
        # Construct the reference part of the JSON payload
        local reference_payload=""
        if [[ -n "$branch" ]]; then
          reference_payload=$(jq -n --arg branch "$branch" '{branch: $branch}')
        elif [[ -n "$ref_tag" ]]; then
          reference_payload=$(jq -n --arg tag "$ref_tag" '{tag: $tag}')
        elif [[ -n "$commit_sha" ]]; then
          reference_payload=$(jq -n --arg sha "$commit_sha" '{commit_sha: $sha}')
        fi

        source_payload=$(jq -n \
            --arg uri "${repo_uri}" \
            --arg dir "$dir" \
            --argjson reference_json "$reference_payload" \
            '{
              developer_connect_source_config: {
                developer_connect_repo_uri: $uri,
                reference: $reference_json
              }
            } | if $dir != "" then .developer_connect_source_config.dir = $dir else . end')

    elif [[ -n "$public_repo_url" ]]; then
        # Validate ref-tag for public-repo-url
        if [[ -z "$ref_tag" ]]; then
            echo "Error: For --public-repo-url, the --ref-tag argument is required."
            return 1
        fi

        source_payload=$(jq -n \
            --arg url "${public_repo_url}" \
            --arg dir "$dir" \
            --arg tag "$ref_tag" \
            '{
              git_source: {
                repo: $url,
                ref_tag: $tag
              }
            } | if $dir != "" then .git_source.dir = $dir else . end')
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)
    
    # Construct the full JSON payload
    PAYLOAD=$(jq -n \
        --arg name "projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/templates/${catalog_template_id}/revisions/${revision_id}" \
        --arg roles_string "$roles" \
        --argjson providers_json "$provider_versions" \
        --arg tf_version "$terraform_version_constraint" \
        --argjson source_json "$source_payload" \
        '{
          "name": $name
        } + $source_json + {
          "metadataInput": {
            "spec": {
              "info": {
                "actuationTool": {
                  "flavor": "Terraform",
                  "version": $tf_version
                }
              },
              "requirements": {
                "roles": {
                  "level": "Project",
                  "roles": ($roles_string | split(","))
                },
                "providerVersions": ($providers_json)
              }
            }
          }
        }')


    # Construct the curl command
    local curl_command="curl -X POST -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" -d '${PAYLOAD}' \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/templates/${catalog_template_id}/revisions?catalog_template_revision_id=${revision_id}\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command and capture the JSON output
    local api_response=$(eval "${curl_command}")

    if [[ $? -ne 0 ]]; then
        echo "Error: Initial API call failed."
        echo "$api_response" | jq '.'
        return 1
    fi

    # The create-revision API returns an LRO, so we extract the LRO name.
    local operation_name=$(echo "$api_response" | jq -r '.name')

    if [[ "$operation_name" == "null" || -z "$operation_name" ]]; then
        echo "Error: Could not extract operation name from response."
        echo "$api_response" | jq '.'
        return 1
    fi
    
    echo "Creation triggered successfully. LRO Name: ${operation_name}"

    if [[ "$wait_for_lro" == "true" ]]; then
        # Call the helper function to poll the LRO
        _poll-lro "$operation_name" "$verbose"
        return $?
    else
        # If not waiting, print the LRO response and exit successfully
        echo "LRO polling not requested. To check status, run: ./adc.sh --function=query-lro --operation-name=\"${operation_name##*/}\""
        echo "$api_response" | jq '.'
        return 0
    fi
}

# Function to list all catalog template revisions.
# Parameters:
#   --space-id <string>: The ID of the space.
#   --catalog-id <string>: The ID of the catalog.
#   --catalog-template-id <string>: The ID of the template.
list-catalog-template-revisions() {
    local space_id=""
    local catalog_id=""
    local catalog_template_id=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --catalog-id=*)
                catalog_id="${1#*=}"
                shift
                ;;
            --catalog-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-id requires an argument."; return 1; fi
                catalog_id="$2"
                shift 2
                ;;
            --catalog-template-id=*)
                catalog_template_id="${1#*=}"
                shift
                ;;
            --catalog-template-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-template-id requires an argument."; return 1; fi
                catalog_template_id="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=list-catalog-template-revisions [--space-id=<string>] [--catalog-id=<string>] --catalog-template-id=<string> [-v|--verbose]"
                echo ""
                echo "Lists all available revisions for a specific catalog template."
                echo ""
                echo "Required parameters:"
                echo "  --catalog-template-id: The ID of the template."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  --catalog-id: The ID of the catalog. Falls back to the CATALOG_ID environment variable."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'list-catalog-template-revisions'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Check for catalog_id, falling back to environment variable
    if [[ -z "$catalog_id" ]]; then
        if [[ -z "$CATALOG_ID" ]]; then
            echo "Error: Required parameter --catalog-id is missing. Please provide it as a command-line argument or set the CATALOG_ID environment variable."
            return 1
        fi
        catalog_id="$CATALOG_ID"
    fi

    # Validate remaining required parameters
    if [[ -z "$catalog_template_id" ]]; then
        echo "Error: Required parameter --catalog-template-id is missing."
        return 1
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the curl command
    local curl_command="curl -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/templates/${catalog_template_id}/revisions\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to delete a specific catalog template revision.
# Parameters:
#   --space-id <string>: The ID of the space.
#   --catalog-id <string>: The ID of the catalog.
#   --catalog-template-id <string>: The ID of the template.
#   --revision-id <string>: The ID of the revision to delete.
delete-catalog-template-revision() {
    local space_id=""
    local catalog_id=""
    local catalog_template_id=""
    local revision_id=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --catalog-id=*)
                catalog_id="${1#*=}"
                shift
                ;;
            --catalog-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-id requires an argument."; return 1; fi
                catalog_id="$2"
                shift 2
                ;;
            --catalog-template-id=*)
                catalog_template_id="${1#*=}"
                shift
                ;;
            --catalog-template-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-template-id requires an argument."; return 1; fi
                catalog_template_id="$2"
                shift 2
                ;;
            --revision-id=*)
                revision_id="${1#*=}"
                shift
                ;;
            --revision-id)
                if [[ -z "$2" ]]; then echo "Error: --revision-id requires an argument."; return 1; fi
                revision_id="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=delete-catalog-template-revision [--space-id=<string>] [--catalog-id=<string>] --catalog-template-id=<string> --revision-id=<string> [-v|--verbose]"
                echo ""
                echo "Deletes a specific catalog template revision."
                echo ""
                echo "Required parameters:"
                echo "  --catalog-template-id: The ID of the template."
                echo "  --revision-id: The ID of the revision to delete."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  --catalog-id: The ID of the catalog. Falls back to the CATALOG_ID environment variable."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'delete-catalog-template-revision'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Check for catalog_id, falling back to environment variable
    if [[ -z "$catalog_id" ]]; then
        if [[ -z "$CATALOG_ID" ]]; then
            echo "Error: Required parameter --catalog-id is missing. Please provide it as a command-line argument or set the CATALOG_ID environment variable."
            return 1
        fi
        catalog_id="$CATALOG_ID"
    fi

    # Validate remaining required parameters
    if [[ -z "$catalog_template_id" || -z "$revision_id" ]]; then
        echo "Error: All required parameters (--catalog-template-id, --revision-id) must be provided."
        return 1
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the curl command
    local curl_command="curl -X DELETE -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" -d '{}' \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/templates/${catalog_template_id}/revisions/${revision_id}\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to create a new share.
# Parameters:
#   --space-id <string>: The ID of the source space.
#   --catalog-id <string>: The ID of the source catalog.
#   --share-id <string>: The ID for the new share.
#   --destination-space-id <string>: The ID of the destination space.
create-share() {
    local space_id=""
    local catalog_id=""
    local share_id=""
    local destination_space_id=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            --catalog-id=*)
                catalog_id="${1#*=}"
                shift
                ;;
            --catalog-id)
                if [[ -z "$2" ]]; then echo "Error: --catalog-id requires an argument."; return 1; fi
                catalog_id="$2"
                shift 2
                ;;
            --share-id=*)
                share_id="${1#*=}"
                shift
                ;;
            --share-id)
                if [[ -z "$2" ]]; then echo "Error: --share-id requires an argument."; return 1; fi
                share_id="$2"
                shift 2
                ;;
            --destination-space-id=*)
                destination_space_id="${1#*=}"
                shift
                ;;
            --destination-space-id)
                if [[ -z "$2" ]]; then echo "Error: --destination-space-id requires an argument."; return 1; fi
                destination_space_id="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=create-share [--space-id=<string>] [--catalog-id=<string>] --share-id=<string> --destination-space-id=<string> [-v|--verbose]"
                echo ""
                echo "Creates a new share, making templates in a catalog available to another space."
                echo ""
                echo "Required parameters:"
                echo "  --share-id: The ID for the new share."
                echo "  --destination-space-id: The ID of the destination space to share with."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  --catalog-id: The ID of the catalog. Falls back to the CATALOG_ID environment variable."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'create-share'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Check for catalog_id, falling back to environment variable
    if [[ -z "$catalog_id" ]]; then
        if [[ -z "$CATALOG_ID" ]]; then
            echo "Error: Required parameter --catalog-id is missing. Please provide it as a command-line argument or set the CATALOG_ID environment variable."
            return 1
        fi
        catalog_id="$CATALOG_ID"
    fi

    # Validate remaining required parameters
    if [[ -z "$share_id" || -z "$destination_space_id" ]]; then
        echo "Error: All required parameters (--share-id, --destination-space-id) must be provided."
        return 1
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the JSON payload
    PAYLOAD=$(jq -n \
        --arg name "projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/shares/${share_id}" \
        --arg dest_space "projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${destination_space_id}" \
        '{
            "name": $name,
            "destination_space": $dest_space
        }')

    # Construct the curl command
    local curl_command="curl -X POST -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" -d '${PAYLOAD}' \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/catalogs/${catalog_id}/shares?share_id=${share_id}\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to list all templates shared with a space.
# Parameters:
#   --space-id <string>: The ID of the space to list shared templates for.
list-shared-templates() {
    local space_id=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --space-id=*)
                space_id="${1#*=}"
                shift
                ;;
            --space-id)
                if [[ -z "$2" ]]; then echo "Error: --space-id requires an argument."; return 1; fi
                space_id="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=list-shared-templates [--space-id=<string>] [-v|--verbose]"
                echo ""
                echo "Lists all templates that have been shared with a specified space."
                echo ""
                echo "Optional parameters:"
                echo "  --space-id: The ID of the space. Falls back to the SPACE_ID environment variable."
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'list-shared-templates'."
                return 1
                ;;
        esac
    done

    # Check for space_id, falling back to environment variable
    if [[ -z "$space_id" ]]; then
        if [[ -z "$SPACE_ID" ]]; then
            echo "Error: Required parameter --space-id is missing. Please provide it as a command-line argument or set the SPACE_ID environment variable."
            return 1
        fi
        space_id="$SPACE_ID"
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)

    # Construct the curl command
    local curl_command="curl -H \"Authorization: Bearer ${TOKEN}\" -H \"Content-Type: application/json\" \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/spaces/${space_id}/sharedTemplates\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# Function to query a long-running operation.
# Parameters:
#   --operation-name <string>: The full operation name to query.
query-lro() {
    local operation_name=""
    local verbose="false"

    # Parse function-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --operation-name=*)
                operation_name="${1#*=}"
                shift
                ;;
            --operation-name)
                if [[ -z "$2" ]]; then echo "Error: --operation-name requires an argument."; return 1; fi
                operation_name="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose="true"
                shift 1
                ;;
            --help)
                echo "Usage: ./adc.sh --function=query-lro --operation-name=<string> [-v|--verbose]"
                echo ""
                echo "Queries the status of a long-running operation."
                echo ""
                echo "Required parameters:"
                echo "  --operation-name: The full resource name of the operation."
                echo ""
                echo "Optional parameters:"
                echo "  -v, --verbose: Prints the full curl command before executing."
                return 0
                ;;
            *)
                echo "Error: Unknown argument '$1' for function 'query-lro'."
                return 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "$operation_name" ]]; then
        echo "Error: Required parameter --operation-name is missing."
        return 1
    fi

    # Get the access token
    TOKEN=$(gcloud auth print-access-token)
    
    # Construct the curl command
    local curl_command="curl -X GET -H \"Authorization: Bearer ${TOKEN}\" \"https://${HOST}/v1alpha/projects/${PROJECT_ID}/locations/${LOCATION_ID}/operations/${operation_name}\""

    # Print the command if verbose flag is set
    if [[ "$verbose" == "true" ]]; then
        echo "Executing command: ${curl_command}"
    fi

    # Execute the curl command
    eval "${curl_command}"

    return $?
}

# --- Main Logic ---
# Check for a PROJECT_ID environment variable.
if [[ -z "$PROJECT_ID" ]]; then
    echo "Error: The PROJECT_ID environment variable is not set. Please set it before running this script."
    exit 1
fi

# Check for a function argument.
if [[ $# -eq 0 || "$1" != "--function="* ]]; then
    usage
fi

# Parse function name and shift the argument.
FUNCTION_CALL="${1#*=}"
shift

# This is where the magic happens. Call the correct function based on the argument.
case "$FUNCTION_CALL" in
    create-space)
        create-space "$@"
        ;;
    list-spaces)
        list-spaces "$@"
        ;;
    create-catalog-template)
        create-catalog-template "$@"
        ;;
    list-catalog-templates)
        list-catalog-templates "$@"
        ;;
    delete-catalog-template)
        delete-catalog-template "$@"
        ;;
    create-catalog-template-revision)
        create-catalog-template-revision "$@"
        ;;
    list-catalog-template-revisions)
        list-catalog-template-revisions "$@"
        ;;
    delete-catalog-template-revision)
        delete-catalog-template-revision "$@"
        ;;
    create-share)
        create-share "$@"
        ;;
    list-shared-templates)
        list-shared-templates "$@"
        ;;
    query-lro)
        query-lro "$@"
        ;;
    *)
        echo "Error: Unknown function '$FUNCTION_CALL'."
        usage
        ;;
esac

exit 0