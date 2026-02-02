import vertexai
import cloudpickle
from google.adk.agents import Agent
import os
import requests
from vertexai.agent_engines import AdkApp
# import asyncio


# 1. Initialize Vertex AI
PROJECT_ID = "adc-gad-byoc-dp"
LOCATION = "us-central1"
file_path = "agent.pkl"
agent_framework = "google-adk"
vertexai.init(project=PROJECT_ID, location=LOCATION)


def web_fetch_tool(url: str) -> str:
    """
    Useful for fetching web content through the corporate proxy on port 443.

    Args:
        url: The full URL of the website to fetch (e.g., 'https://google.com').
    """
    # Get the Proxy IP from environment variables
    proxy_ip = os.environ.get("PROXY_IP")
    
    # If PROXY_IP is present, configure the proxy dictionary using port 443
    proxies = None
    if proxy_ip:
        # Note: Even if the proxy is on 443, the protocol for the 
        # proxy connection itself is usually defined as http://
        proxy_address = f"http://{proxy_ip}:443"
        proxies = {
            "http": proxy_address,
            "https": proxy_address,
        }
    
    try:
        # 3. Perform the request
        # Setting verify=True is recommended; SWP uses certificates for TLS inspection if configured
        response = requests.get(url, proxies=proxies, timeout=10)
        
        return {
            "status": "success",
            "target_url": url,
            "proxy_used": proxy_ip,
            "http_code": response.status_code,
            "content_preview": response.text[:100] # First 100 chars
        }

    except Exception as e:
        return {
            "status": "failed",
            "target_url": url,
            "proxy_used": proxy_ip,
            "error": str(e)
        }


# 2. Define a Tool to check environment variables at RUNTIME
def check_environment_tool() -> str:
    """Useful for debugging. Returns the current environment variables."""
    # We filter for specific keys to avoid dumping sensitive system tokens
    # Or just return a specific one you expect from SWP
    proxy_ip = os.environ.get("PROXY_IP", "Variable not found")
    return f"The value of Proxy IP is: {proxy_ip}"

# 2. Define the Agent logic using ADK
# For a "Hello World", we just need a simple agent configuration
def create_hello_world_agent():
    # In ADK, we can define a simple tool-less agent
    # or just a basic interaction model.
    model = "gemini-2.0-flash-001"
    
    # We wrap the agent logic in an AdkApp
    # This prepares it for the Vertex AI Agent Engine environment
    agent = Agent(
        model=model,
        name="hello_world_agent",
        tools=[check_environment_tool, web_fetch_tool],
        description="A simple Hello World agent using ADK",
    )
    return AdkApp(agent=agent)


def main():
    app = create_hello_world_agent()
    # 3. Serialize the agent application using cloudpickle
    with open(file_path, "wb") as f:
        cloudpickle.dump(app, f)
    # async for event in app.async_stream_query(
    #     user_id="USER_ID",  # Required
    #     message="Can you call youtube.com and give the response?",
    #     ):
    #     print(event)

if __name__ == "__main__":
    # asyncio.run(main())
    main()