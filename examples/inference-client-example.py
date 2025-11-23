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
Example: Client code for calling inference services
Supports Triton, vLLM, and TGI inference servers
"""

import requests
import json
from typing import Dict, List, Optional

class InferenceClient:
    def __init__(self, base_url: str, service_type: str = "vllm"):
        """
        Initialize inference client
        
        Args:
            base_url: Base URL of the inference service
            service_type: Type of service (vllm, triton, tgi)
        """
        self.base_url = base_url
        self.service_type = service_type
    
    def generate(self, prompt: str, max_tokens: int = 100, temperature: float = 0.7) -> Dict:
        """
        Generate text from a prompt
        
        Args:
            prompt: Input prompt
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
        
        Returns:
            Generated text response
        """
        if self.service_type == "vllm" or self.service_type == "tgi":
            # OpenAI-compatible API
            response = requests.post(
                f"{self.base_url}/v1/completions",
                json={
                    "model": "llama2-7b",
                    "prompt": prompt,
                    "max_tokens": max_tokens,
                    "temperature": temperature
                },
                headers={"Content-Type": "application/json"}
            )
            return response.json()
        
        elif self.service_type == "triton":
            # Triton Inference Server API
            response = requests.post(
                f"{self.base_url}/v2/models/llama2-7b/infer",
                json={
                    "inputs": [
                        {
                            "name": "text_input",
                            "shape": [1],
                            "datatype": "BYTES",
                            "data": [prompt]
                        }
                    ],
                    "outputs": [
                        {
                            "name": "text_output"
                        }
                    ]
                }
            )
            return response.json()
    
    def chat(self, messages: List[Dict], max_tokens: int = 100, temperature: float = 0.7) -> Dict:
        """
        Chat completion (for vLLM and TGI)
        
        Args:
            messages: List of message dictionaries
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
        
        Returns:
            Chat completion response
        """
        response = requests.post(
            f"{self.base_url}/v1/chat/completions",
            json={
                "model": "llama2-7b",
                "messages": messages,
                "max_tokens": max_tokens,
                "temperature": temperature
            },
            headers={"Content-Type": "application/json"}
        )
        return response.json()


# Example usage
if __name__ == "__main__":
    # vLLM inference
    vllm_client = InferenceClient(
        base_url="http://vllm-inference-server.inference.svc.cluster.local:8000",
        service_type="vllm"
    )
    
    result = vllm_client.generate(
        prompt="What is machine learning?",
        max_tokens=150,
        temperature=0.7
    )
    print(json.dumps(result, indent=2))
    
    # Chat completion
    chat_result = vllm_client.chat(
        messages=[
            {"role": "user", "content": "Explain transformer architecture"}
        ],
        max_tokens=200
    )
    print(json.dumps(chat_result, indent=2))

