import os
import shutil
import subprocess
from datetime import datetime
import argparse
import logging
from typing import List, Optional

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class CodeDeployer:
    def __init__(self, source_dir: str, deploy_dir: str, backup_dir: str):
        self.source_dir = os.path.abspath(source_dir)
        self.deploy_dir = os.path.abspath(deploy_dir)
        self.backup_dir = os.path.abspath(backup_dir)
        
        # Create directories if they don't exist
        os.makedirs(self.deploy_dir, exist_ok=True)
        os.makedirs(self.backup_dir, exist_ok=True)
    
    def create_backup(self) -> str:
        """Create a backup of the current deployment"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = os.path.join(self.backup_dir, f"backup_{timestamp}")
        
        logger.info(f"Creating backup at {backup_path}")
        shutil.copytree(self.deploy_dir, backup_path)
        return backup_path
    
    def run_tests(self) -> bool:
        """Run tests in the source directory"""
        logger.info("Running tests...")
        try:
            # Assuming there's a test command like 'python -m pytest'
            result = subprocess.run(
                ["python", "-m", "pytest", "tests/"],
                cwd=self.source_dir,
                check=True,
                capture_output=True,
                text=True
            )
            logger.info("Tests passed successfully")
            logger.debug(f"Test output:\n{result.stdout}")
            return True
        except subprocess.CalledProcessError as e:
            logger.error(f"Tests failed:\n{e.stderr}")
            return False
    
    def deploy(self, skip_tests: bool = False) -> bool:
        """Deploy the code from source to deployment directory"""
        try:
            # Step 1: Run tests (unless skipped)
            if not skip_tests and not self.run_tests():
                return False
            
            # Step 2: Create backup
            self.create_backup()
            
            # Step 3: Clean deploy directory (except for excluded files)
            logger.info(f"Cleaning deploy directory: {self.deploy_dir}")
            for item in os.listdir(self.deploy_dir):
                item_path = os.path.join(self.deploy_dir, item)
                if os.path.isfile(item_path):
                    os.unlink(item_path)
                elif os.path.isdir(item_path):
                    shutil.rmtree(item_path)
            
            # Step 4: Copy files from source to deploy
            logger.info(f"Copying files from {self.source_dir} to {self.deploy_dir}")
            for item in os.listdir(self.source_dir):
                source_item = os.path.join(self.source_dir, item)
                deploy_item = os.path.join(self.deploy_dir, item)
                
                if os.path.isdir(source_item):
                    shutil.copytree(source_item, deploy_item)
                else:
                    shutil.copy2(source_item, deploy_item)
            
            # Step 5: Run post-deploy script if exists
            post_deploy_script = os.path.join(self.source_dir, "post_deploy.sh")
            if os.path.exists(post_deploy_script):
                logger.info("Running post-deploy script")
                subprocess.run(["bash", post_deploy_script], cwd=self.deploy_dir, check=True)
            
            logger.info("Deployment completed successfully!")
            return True
            
        except Exception as e:
            logger.error(f"Deployment failed: {str(e)}")
            return False

def main():
    parser = argparse.ArgumentParser(description="Code Deployment Tool")
    parser.add_argument("--source", required=True, help="Source directory containing code to deploy")
    parser.add_argument("--deploy", required=True, help="Target deployment directory")
    parser.add_argument("--backup", required=True, help="Backup directory for previous versions")
    parser.add_argument("--skip-tests", action="store_true", help="Skip running tests before deployment")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose logging")
    
    args = parser.parse_args()
    
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    deployer = CodeDeployer(args.source, args.deploy, args.backup)
    success = deployer.deploy(skip_tests=args.skip_tests)
    
    if not success:
        logger.error("Deployment failed. Check logs for details.")
        exit(1)

if __name__ == "__main__":
    main()
