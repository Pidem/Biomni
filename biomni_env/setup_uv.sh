#!/bin/bash

# BioAgentOS - Biomni Environment Setup Script (UV Version)
# This script sets up a comprehensive bioinformatics environment using uv package manager

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default tools directory is the current directory
DEFAULT_TOOLS_DIR="$(pwd)/biomni_tools"
TOOLS_DIR=""

echo -e "${YELLOW}=== Biomni Environment Setup (UV Version) ===${NC}"
echo -e "${BLUE}This script will set up a comprehensive bioinformatics environment using uv package manager.${NC}"

# Check if uv is installed
if ! command -v uv &> /dev/null; then
    echo -e "${RED}Error: uv is not installed or not in PATH.${NC}"
    echo "Please install uv first:"
    echo "curl -LsSf https://astral.sh/uv/install.sh | sh"
    echo "Or visit: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
fi

# Function to handle errors
handle_error() {
    local exit_code=$1
    local error_message=$2
    local optional=${3:-false}

    if [ $exit_code -ne 0 ]; then
        echo -e "${RED}Error: $error_message${NC}"
        if [ "$optional" = true ]; then
            echo -e "${YELLOW}Continuing with setup as this component is optional.${NC}"
            return 0
        else
            if [ -z "$NON_INTERACTIVE" ]; then
                read -p "Continue with setup? (y/n) " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    echo -e "${RED}Setup aborted.${NC}"
                    exit 1
                fi
            else
                echo -e "${YELLOW}Non-interactive mode: continuing despite error.${NC}"
            fi
        fi
    fi
    return $exit_code
}

# Function to setup Python environment with uv
setup_python_env() {
    echo -e "\n${BLUE}=== Setting up Python Environment with UV ===${NC}"
    
    # Navigate to project root (parent directory)
    cd ..
    
    echo -e "${YELLOW}Creating virtual environment with Python 3.11...${NC}"
    uv venv --python 3.11 .venv
    handle_error $? "Failed to create virtual environment."
    
    echo -e "${YELLOW}Activating virtual environment...${NC}"
    source .venv/bin/activate
    
    echo -e "${YELLOW}Installing Python dependencies from pyproject.toml...${NC}"
    uv sync
    handle_error $? "Failed to install Python dependencies."
    
    echo -e "${GREEN}Successfully set up Python environment!${NC}"
    
    # Go back to biomni_env directory
    cd biomni_env
}

# Function to install system dependencies (bioinformatics tools)
install_system_deps() {
    echo -e "\n${BLUE}=== Installing System Dependencies ===${NC}"
    
    # Check if we're on macOS or Linux
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command -v brew &> /dev/null; then
            echo -e "${RED}Error: Homebrew is not installed.${NC}"
            echo "Please install Homebrew first: https://brew.sh/"
            return 1
        fi
        
        echo -e "${YELLOW}Installing bioinformatics tools via Homebrew...${NC}"
        
        # Install bioinformatics tools available via Homebrew
        brew install blast samtools bowtie2 bwa bedtools fastqc trimmomatic mafft
        handle_error $? "Failed to install some bioinformatics tools via Homebrew." true
        
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo -e "${YELLOW}Installing bioinformatics tools via system package manager...${NC}"
        
        # Try to detect the package manager
        if command -v apt-get &> /dev/null; then
            # Ubuntu/Debian
            sudo apt-get update
            sudo apt-get install -y ncbi-blast+ samtools bowtie2 bwa bedtools fastqc trimmomatic mafft
            handle_error $? "Failed to install some bioinformatics tools via apt." true
        elif command -v yum &> /dev/null; then
            # CentOS/RHEL
            sudo yum install -y ncbi-blast+ samtools bowtie2 bwa bedtools fastqc trimmomatic mafft
            handle_error $? "Failed to install some bioinformatics tools via yum." true
        elif command -v dnf &> /dev/null; then
            # Fedora
            sudo dnf install -y ncbi-blast+ samtools bowtie2 bwa bedtools fastqc trimmomatic mafft
            handle_error $? "Failed to install some bioinformatics tools via dnf." true
        else
            echo -e "${YELLOW}Could not detect package manager. You may need to install bioinformatics tools manually.${NC}"
        fi
    else
        echo -e "${YELLOW}Unsupported OS. You may need to install bioinformatics tools manually.${NC}"
    fi
}

# Function to install CLI tools
install_cli_tools() {
    echo -e "\n${BLUE}=== Installing Command-Line Bioinformatics Tools ===${NC}"

    # Ask user for the directory to install CLI tools
    if [ -z "$NON_INTERACTIVE" ]; then
        echo -e "${YELLOW}Where would you like to install the command-line tools?${NC}"
        echo -e "${BLUE}Default: $DEFAULT_TOOLS_DIR${NC}"
        read -p "Enter directory path (or press Enter for default): " user_tools_dir
    else
        user_tools_dir=""
        echo -e "${YELLOW}Non-interactive mode: using default directory $DEFAULT_TOOLS_DIR for CLI tools.${NC}"
    fi

    if [ -z "$user_tools_dir" ]; then
        TOOLS_DIR="$DEFAULT_TOOLS_DIR"
    else
        TOOLS_DIR="$user_tools_dir"
    fi

    # Export the tools directory for the CLI tools installer
    export BIOMNI_TOOLS_DIR="$TOOLS_DIR"

    echo -e "${YELLOW}Installing command-line tools (PLINK, IQ-TREE, GCTA, etc.) to $TOOLS_DIR...${NC}"

    # Set environment variable to skip prompts in the CLI tools installer
    export BIOMNI_AUTO_INSTALL=1

    # Run the CLI tools installer
    bash install_cli_tools.sh
    handle_error $? "Failed to install CLI tools." true

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully installed command-line tools!${NC}"

        # Create a setup_path.sh file in the current directory
        echo "#!/bin/bash" > setup_path.sh
        echo "# Added by biomni setup" >> setup_path.sh
        echo "# Remove any old paths first to avoid duplicates" >> setup_path.sh
        echo "PATH=\$(echo \$PATH | tr ':' '\n' | grep -v \"biomni_tools/bin\" | tr '\n' ':' | sed 's/:$//')" >> setup_path.sh
        echo "export PATH=\"$TOOLS_DIR/bin:\$PATH\"" >> setup_path.sh
        chmod +x setup_path.sh

        echo -e "${GREEN}Created setup_path.sh in the current directory.${NC}"
        echo -e "${YELLOW}You can add the tools to your PATH by running:${NC}"
        echo -e "${GREEN}source $(pwd)/setup_path.sh${NC}"

        # Also add to the current session
        # Remove any old paths first to avoid duplicates
        PATH=$(echo $PATH | tr ':' '\n' | grep -v "biomni_tools/bin" | tr '\n' ':' | sed 's/:$//')
        export PATH="$TOOLS_DIR/bin:$PATH"
    fi

    # Unset the environment variables
    unset BIOMNI_AUTO_INSTALL
    unset BIOMNI_TOOLS_DIR
}

# Function to install R packages
install_r_packages() {
    echo -e "\n${BLUE}=== Installing R Packages ===${NC}"
    
    if [ -z "$NON_INTERACTIVE" ]; then
        read -p "Do you want to install R packages? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}Skipping R packages installation.${NC}"
            return 0
        fi
    fi

    # Check if R is installed
    if ! command -v R &> /dev/null; then
        echo -e "${YELLOW}R is not installed. Installing R...${NC}"
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install r
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get install -y r-base r-base-dev
            elif command -v yum &> /dev/null; then
                sudo yum install -y R R-devel
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y R R-devel
            fi
        fi
        
        handle_error $? "Failed to install R." true
    fi

    if command -v R &> /dev/null; then
        echo -e "${YELLOW}Installing R packages...${NC}"
        Rscript install_r_packages.R
        handle_error $? "Failed to install R packages." true
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Successfully installed R packages!${NC}"
        fi
    fi
}

# Main setup function
main() {
    echo -e "${BLUE}Starting Biomni environment setup...${NC}"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --non-interactive)
                NON_INTERACTIVE=1
                shift
                ;;
            --help)
                echo "Usage: $0 [--non-interactive] [--help]"
                echo "  --non-interactive  Run setup without prompts"
                echo "  --help            Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    # Setup Python environment
    setup_python_env
    
    # Install system dependencies
    install_system_deps
    
    # Install CLI tools
    install_cli_tools
    
    # Install R packages
    install_r_packages
    
    echo -e "\n${GREEN}=== Setup Complete! ===${NC}"
    echo -e "${YELLOW}To activate the environment in the future, run:${NC}"
    echo -e "${GREEN}source .venv/bin/activate${NC}"
    echo -e "${YELLOW}To add CLI tools to PATH, run:${NC}"
    echo -e "${GREEN}source biomni_env/setup_path.sh${NC}"
    echo -e "\n${BLUE}You can now install biomni with:${NC}"
    echo -e "${GREEN}pip install biomni --upgrade${NC}"
}

# Run main function
main "$@"
