#!/bin/bash

# Chaos Engineering Infrastructure Deployment Script
# This script deploys the complete chaos engineering stack in the correct order

set -euo pipefail

# Configuration
NAMESPACE_OBSERVABILITY="observability"
NAMESPACE_LITMUS="litmus"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi

    # Check if cluster is accessible
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi

    # Check if required namespaces exist
    if ! kubectl get namespace $NAMESPACE_OBSERVABILITY &> /dev/null; then
        log_error "Namespace $NAMESPACE_OBSERVABILITY does not exist"
        exit 1
    fi

    # Check if Prometheus is running (required for monitoring)
    if ! kubectl get pods -n $NAMESPACE_OBSERVABILITY -l app.kubernetes.io/name=prometheus &> /dev/null; then
        log_warning "Prometheus not found - some monitoring features may not work"
    fi

    log_success "Prerequisites check completed"
}

# Deploy Chaos Mesh
deploy_chaos_mesh() {
    log_info "Deploying Chaos Mesh..."

    kubectl apply -f "$SCRIPT_DIR/chaos-mesh.yaml"

    # Wait for Chaos Mesh to be ready
    log_info "Waiting for Chaos Mesh to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=chaos-mesh -n chaos-mesh --timeout=300s || {
        log_warning "Chaos Mesh pods may still be starting up"
    }

    log_success "Chaos Mesh deployed successfully"
}

# Deploy Litmus
deploy_litmus() {
    log_info "Deploying Litmus..."

    kubectl apply -f "$SCRIPT_DIR/litmus.yaml"

    # Wait for Litmus to be ready
    log_info "Waiting for Litmus to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=litmus -n $NAMESPACE_LITMUS --timeout=300s || {
        log_warning "Litmus pods may still be starting up"
    }

    log_success "Litmus deployed successfully"
}

# Deploy chaos experiments
deploy_chaos_experiments() {
    log_info "Deploying chaos experiments..."

    kubectl apply -f "$SCRIPT_DIR/chaos-experiments.yaml"

    log_success "Chaos experiments deployed successfully"
}

# Deploy chaos schedules
deploy_chaos_schedules() {
    log_info "Deploying chaos schedules..."

    kubectl apply -f "$SCRIPT_DIR/chaos-schedules.yaml"

    log_success "Chaos schedules deployed successfully"
}

# Deploy disaster recovery tests
deploy_disaster_recovery_tests() {
    log_info "Deploying disaster recovery tests..."

    kubectl apply -f "$SCRIPT_DIR/disaster-recovery-tests.yaml"

    log_success "Disaster recovery tests deployed successfully"
}

# Deploy performance tests
deploy_performance_tests() {
    log_info "Deploying performance tests..."

    kubectl apply -f "$SCRIPT_DIR/performance-tests.yaml"

    log_success "Performance tests deployed successfully"
}

# Deploy resilience tests
deploy_resilience_tests() {
    log_info "Deploying resilience tests..."

    kubectl apply -f "$SCRIPT_DIR/resilience-tests.yaml"

    log_success "Resilience tests deployed successfully"
}

# Verify deployment
verify_deployment() {
    log_info "Verifying chaos engineering deployment..."

    # Check Chaos Mesh
    if kubectl get pods -n chaos-mesh -l app.kubernetes.io/name=chaos-mesh | grep -q Running; then
        log_success "Chaos Mesh is running"
    else
        log_warning "Chaos Mesh may not be fully ready"
    fi

    # Check Litmus
    if kubectl get pods -n $NAMESPACE_LITMUS -l app.kubernetes.io/name=litmus | grep -q Running; then
        log_success "Litmus is running"
    else
        log_warning "Litmus may not be fully ready"
    fi

    # Check if chaos schedules are created
    schedule_count=$(kubectl get chaosschedules -n $NAMESPACE_OBSERVABILITY --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$schedule_count" -gt 0 ]; then
        log_success "Found $schedule_count chaos schedules"
    else
        log_warning "No chaos schedules found"
    fi

    # Check workflow templates
    workflow_count=$(kubectl get workflowtemplates -n $NAMESPACE_OBSERVABILITY --no-headers 2>/dev/null | wc -l || echo "0")
    if [ "$workflow_count" -gt 0 ]; then
        log_success "Found $workflow_count workflow templates"
    else
        log_warning "No workflow templates found"
    fi

    log_success "Deployment verification completed"
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy chaos engineering infrastructure components.

OPTIONS:
    -h, --help              Show this help message
    -v, --verify-only       Only verify existing deployment
    -c, --chaos-mesh-only   Deploy only Chaos Mesh
    -l, --litmus-only       Deploy only Litmus
    -a, --all               Deploy all components (default)
    --skip-verification     Skip deployment verification

EXAMPLES:
    $0                      Deploy all components
    $0 --chaos-mesh-only    Deploy only Chaos Mesh
    $0 --verify-only        Verify existing deployment
    $0 --skip-verification  Deploy without verification

EOF
}

# Parse command line arguments
VERIFY_ONLY=false
CHAOS_MESH_ONLY=false
LITMUS_ONLY=false
SKIP_VERIFICATION=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_usage
            exit 0
            ;;
        -v|--verify-only)
            VERIFY_ONLY=true
            shift
            ;;
        -c|--chaos-mesh-only)
            CHAOS_MESH_ONLY=true
            shift
            ;;
        -l|--litmus-only)
            LITMUS_ONLY=true
            shift
            ;;
        --skip-verification)
            SKIP_VERIFICATION=true
            shift
            ;;
        -a|--all)
            # Default behavior
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    log_info "Starting chaos engineering deployment..."

    check_prerequisites

    if [ "$VERIFY_ONLY" = true ]; then
        verify_deployment
        exit 0
    fi

    if [ "$CHAOS_MESH_ONLY" = true ]; then
        deploy_chaos_mesh
    elif [ "$LITMUS_ONLY" = true ]; then
        deploy_litmus
    else
        # Deploy all components in order
        deploy_chaos_mesh
        deploy_litmus

        # Wait a bit for operators to be ready
        log_info "Waiting for operators to be ready before deploying experiments..."
        sleep 30

        deploy_chaos_experiments
        deploy_chaos_schedules
        deploy_disaster_recovery_tests
        deploy_performance_tests
        deploy_resilience_tests
    fi

    if [ "$SKIP_VERIFICATION" = false ]; then
        sleep 10
        verify_deployment
    fi

    log_success "Chaos engineering deployment completed!"

    # Show next steps
    cat << EOF

${GREEN}Next Steps:${NC}
1. Verify all pods are running:
   kubectl get pods -n chaos-mesh
   kubectl get pods -n $NAMESPACE_LITMUS
   kubectl get pods -n $NAMESPACE_OBSERVABILITY

2. Check chaos schedules:
   kubectl get chaosschedules -n $NAMESPACE_OBSERVABILITY

3. Monitor chaos experiments:
   kubectl get chaosengines -A

4. Run disaster recovery test:
   argo submit disaster-recovery-full-test

5. Access Chaos Mesh dashboard (if configured):
   kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333

${YELLOW}Important Notes:${NC}
- Chaos experiments will run according to their schedules
- Monitor system behavior through Grafana dashboards
- Review alerts in Prometheus for any issues
- Check incident response procedures are working

EOF
}

# Run main function
main "$@"