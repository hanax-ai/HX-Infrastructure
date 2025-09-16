#!/usr/bin/env python3
"""
LiteLLM API Gateway - Example Integration Script
This script demonstrates various ways to interact with the LiteLLM API Gateway

REQUIRED: Set LITELLM_API_KEY environment variable before running:
  export LITELLM_API_KEY='your-actual-api-key'

Dependencies:
  pip install openai python-dotenv
"""

import os
import sys
import json
import asyncio
from typing import List, Dict, Any
from openai import OpenAI, AsyncOpenAI

# Optional: Load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass  # python-dotenv is optional

# Configuration
API_BASE = "http://hx-api-server.dev-test.hana-x.ai:4000/v1"

# Get API key from environment - no defaults allowed for security
API_KEY = os.getenv("LITELLM_API_KEY")
if not API_KEY:
    print("\nERROR: LITELLM_API_KEY environment variable is required but not set.", file=sys.stderr)
    print("\nTo fix this issue:", file=sys.stderr)
    print("1. Export the variable: export LITELLM_API_KEY='your-actual-api-key'", file=sys.stderr)
    print("2. Or create a .env file (see .env.example for template)", file=sys.stderr)
    print("3. Install python-dotenv: pip install python-dotenv", file=sys.stderr)
    print("4. See documentation at: docs/litellm-integration.md", file=sys.stderr)
    sys.exit(1)

# Initialize clients
client = OpenAI(base_url=API_BASE, api_key=API_KEY)
async_client = AsyncOpenAI(base_url=API_BASE, api_key=API_KEY)


def example_1_simple_chat():
    """Basic chat completion example"""
    print("\n=== Example 1: Simple Chat ===")
    
    response = client.chat.completions.create(
        model="phi3-3.8b",
        messages=[
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": "What is the capital of France?"}
        ],
        temperature=0.7,
        max_tokens=100
    )
    
    print(f"Response: {response.choices[0].message.content}")
    print(f"Tokens used: {response.usage.total_tokens}")


def example_2_streaming_chat():
    """Streaming chat completion example"""
    print("\n=== Example 2: Streaming Chat ===")
    
    stream = client.chat.completions.create(
        model="llama3-8b",
        messages=[
            {"role": "user", "content": "Write a haiku about programming"}
        ],
        stream=True,
        temperature=0.9
    )
    
    print("Response: ", end="")
    for chunk in stream:
        if chunk.choices[0].delta.content:
            print(chunk.choices[0].delta.content, end="")
    print()


def example_3_conversation_history():
    """Multi-turn conversation example"""
    print("\n=== Example 3: Conversation with History ===")
    
    conversation = [
        {"role": "system", "content": "You are a Python programming expert."},
        {"role": "user", "content": "What is a decorator in Python?"},
    ]
    
    # First turn
    response = client.chat.completions.create(
        model="mistral-7b",
        messages=conversation,
        max_tokens=200
    )
    
    assistant_reply = response.choices[0].message.content
    print(f"Assistant: {assistant_reply}")
    
    # Add to conversation history
    conversation.append({"role": "assistant", "content": assistant_reply})
    conversation.append({"role": "user", "content": "Can you show me a simple example?"})
    
    # Second turn
    response = client.chat.completions.create(
        model="mistral-7b",
        messages=conversation,
        max_tokens=300
    )
    
    print(f"\nAssistant: {response.choices[0].message.content}")


async def example_4_async_batch():
    """Async batch processing example"""
    print("\n=== Example 4: Async Batch Processing ===")
    
    prompts = [
        "Explain quantum computing in one sentence",
        "What is machine learning?",
        "Define artificial intelligence",
        "What is the difference between AI and ML?"
    ]
    
    async def process_prompt(prompt: str, model: str = "gemma2-9b"):
        response = await async_client.chat.completions.create(
            model=model,
            messages=[{"role": "user", "content": prompt}],
            max_tokens=100
        )
        return prompt, response.choices[0].message.content
    
    # Process all prompts concurrently
    tasks = [process_prompt(prompt) for prompt in prompts]
    results = await asyncio.gather(*tasks)
    
    for prompt, response in results:
        print(f"\nQ: {prompt}")
        print(f"A: {response}")


def example_5_model_comparison():
    """Compare responses from different models"""
    print("\n=== Example 5: Model Comparison ===")
    
    prompt = "Explain the concept of recursion in programming"
    models = ["phi3-3.8b", "llama3-8b", "mistral-7b"]
    
    for model in models:
        print(f"\n--- {model} ---")
        try:
            response = client.chat.completions.create(
                model=model,
                messages=[{"role": "user", "content": prompt}],
                max_tokens=150,
                temperature=0.7
            )
            print(response.choices[0].message.content)
        except Exception as e:
            print(f"Error with {model}: {e}")


def example_6_error_handling():
    """Demonstrate proper error handling"""
    print("\n=== Example 6: Error Handling ===")
    
    # Test with invalid model
    try:
        response = client.chat.completions.create(
            model="invalid-model",
            messages=[{"role": "user", "content": "Hello"}]
        )
    except Exception as e:
        print(f"Expected error for invalid model: {type(e).__name__}: {e}")
    
    # Test with empty messages
    try:
        response = client.chat.completions.create(
            model="phi3-3.8b",
            messages=[]
        )
    except Exception as e:
        print(f"Expected error for empty messages: {type(e).__name__}: {e}")
    
    # Test with proper retry logic
    import time
    from openai import RateLimitError
    
    max_retries = 3
    retry_delay = 1
    
    for attempt in range(max_retries):
        try:
            response = client.chat.completions.create(
                model="llama3-8b",
                messages=[{"role": "user", "content": "Hello"}],
                max_tokens=50
            )
            print(f"Success on attempt {attempt + 1}")
            break
        except RateLimitError as e:
            if attempt < max_retries - 1:
                print(f"Rate limit hit, retrying in {retry_delay} seconds...")
                time.sleep(retry_delay)
                retry_delay *= 2  # Exponential backoff
            else:
                print(f"Failed after {max_retries} attempts")
                raise


def example_7_advanced_parameters():
    """Demonstrate advanced parameters"""
    print("\n=== Example 7: Advanced Parameters ===")
    
    response = client.chat.completions.create(
        model="llama3-8b",
        messages=[
            {"role": "system", "content": "You are a creative writer."},
            {"role": "user", "content": "Write a story about a robot learning to paint."}
        ],
        temperature=1.2,          # Higher creativity
        max_tokens=200,
        top_p=0.9,               # Nucleus sampling
        frequency_penalty=0.5,    # Reduce repetition
        presence_penalty=0.3,     # Encourage new topics
        stop=["\n\n", "THE END"]  # Stop sequences
    )
    
    print(f"Creative response: {response.choices[0].message.content}")
    print(f"\nFinish reason: {response.choices[0].finish_reason}")


def list_available_models():
    """List all available models"""
    print("\n=== Available Models ===")
    
    try:
        models = client.models.list()
        for model in models.data:
            print(f"- {model.id}")
    except Exception as e:
        print(f"Error listing models: {e}")


def main():
    """Run all examples"""
    print("LiteLLM API Gateway Integration Examples")
    print("=" * 50)
    
    # Check API key
    if API_KEY == "sk-1234567890abcdef-test-key-please-replace":
        print("\nWARNING: Using default API key. Set LITELLM_API_KEY environment variable.")
    
    # List available models
    list_available_models()
    
    # Run synchronous examples
    example_1_simple_chat()
    example_2_streaming_chat()
    example_3_conversation_history()
    example_5_model_comparison()
    example_6_error_handling()
    example_7_advanced_parameters()
    
    # Run async example
    print("\nRunning async example...")
    asyncio.run(example_4_async_batch())
    
    print("\n" + "=" * 50)
    print("All examples completed successfully!")


if __name__ == "__main__":
    main()