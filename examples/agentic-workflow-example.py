# Copyright 2024 [your name/company]
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""
Example: Agentic AI workflow using CrewAI
This example shows how to use CrewAI for multi-agent collaboration
"""

import requests
import json
from typing import List, Dict

class CrewAIClient:
    def __init__(self, base_url: str = "http://crewai-orchestrator.agentic.svc.cluster.local:8000"):
        self.base_url = base_url
    
    def create_task(self, description: str, agents: List[str]) -> Dict:
        """
        Create a new task for agents
        
        Args:
            description: Task description
            agents: List of agent names to assign
        
        Returns:
            Task creation response
        """
        response = requests.post(
            f"{self.base_url}/tasks",
            json={
                "description": description,
                "agents": agents
            }
        )
        return response.json()
    
    def execute_workflow(self, workflow_id: str) -> Dict:
        """
        Execute a workflow
        
        Args:
            workflow_id: Workflow ID to execute
        
        Returns:
            Workflow execution result
        """
        response = requests.post(
            f"{self.base_url}/workflows/{workflow_id}/execute"
        )
        return response.json()
    
    def get_status(self, task_id: str) -> Dict:
        """
        Get task status
        
        Args:
            task_id: Task ID
        
        Returns:
            Task status
        """
        response = requests.get(
            f"{self.base_url}/tasks/{task_id}/status"
        )
        return response.json()


# Example: Research and writing workflow
if __name__ == "__main__":
    client = CrewAIClient()
    
    # Create a research task
    research_task = client.create_task(
        description="Research the latest developments in large language models",
        agents=["researcher"]
    )
    print(f"Research task created: {research_task['task_id']}")
    
    # Create a writing task
    writing_task = client.create_task(
        description="Write a comprehensive article based on the research",
        agents=["writer"]
    )
    print(f"Writing task created: {writing_task['task_id']}")
    
    # Create a review task
    review_task = client.create_task(
        description="Review and improve the article",
        agents=["reviewer"]
    )
    print(f"Review task created: {review_task['task_id']}")
    
    # Execute workflow
    workflow_result = client.execute_workflow(
        workflow_id="research-writing-workflow"
    )
    print(json.dumps(workflow_result, indent=2))

