import os
import asyncio
import os

import cloudpickle
import requests
import vertexai
from google.adk.agents import Agent
from google.adk.tools import AgentTool, google_search
from vertexai.agent_engines import AdkApp
import yfinance as yf



# Initialize Vertex AI
PROJECT_ID = "adc-gad-byoc-dp"
LOCATION = "us-central1"
file_path = "agent.pkl"
agent_framework = "google-adk"
vertexai.init(project=PROJECT_ID, location=LOCATION)
model = "gemini-2.0-flash-001"


def web_fetch_tool(url: str) -> dict:
    """Fetch web content, using an optional corporate proxy on port 443.

    Args:
        url: Full URL to fetch (e.g., 'https://example.com').

    Returns:
        A dict with status and a short preview or error details.
    """
    proxy_ip = os.environ.get("PROXY_IP")
    proxies = None
    if proxy_ip:
        # Proxy protocol is usually http even if the proxy listens on 443.
        proxy_address = f"http://{proxy_ip}:443"
        proxies = {"http": proxy_address, "https": proxy_address}

    try:
        response = requests.get(url, proxies=proxies, timeout=10)
        return {
            "status": "success",
            "target_url": url,
            "proxy_used": proxy_ip,
            "http_code": response.status_code,
            "content_preview": response.text[:100],
        }
    except Exception as exc:  # pragma: no cover - runtime network errors
        return {
            "status": "failed",
            "target_url": url,
            "proxy_used": proxy_ip,
            "error": str(exc),
        }

def get_stock_price(ticker: str, interval: str = "1y") -> dict:
    """Fetch stock price data for a given ticker and interval.
    
    Args:
        ticker: Stock ticker symbol (e.g., 'AAPL').
        interval: Data interval (e.g., '1d', '5d', '1mo', '3mo', '6mo', '1y', '2y', '5y', '10y', 'ytd', 'max').
    Returns:
        A dict containing stock price data or error information.
        """
    try:
        stock = yf.Ticker(ticker)
        hist = stock.history(period=interval)
        if hist.empty:
            return {"error": f"No data found for ticker {ticker}"}
        return {
            "ticker": ticker,
            "interval": interval,
            "data": hist.to_dict(orient="records"),
        }
    except Exception as e:
        return {"error": f"Failed to fetch data for ticker {ticker}: {e}"}


def get_agent() -> AdkApp:
    """Build and return the root AdkApp containing sub-agents."""
    news_agent = Agent(
        name="news_analyst",
        model=model,
        tools=[google_search],
        instruction="Analyze recent sentiment for the given ticker.",
    )

    fundamental_agent = Agent(
        name="fundamental_analyst",
        model=model,
        tools=[google_search],
        instruction=(
            "Analyze financial health and valuation for the given ticker."
        ),
    )

    technical_agent = Agent(
        name="technical_analyst",
        model=model,
        tools=[get_stock_price],
        instruction=(
            "Analyze stock price trends and technical indicators for the given ticker."
        ),
    )

    root_agent = Agent(
        name="stock_strategist",
        model=model,
        tools=[AgentTool(agent=news_agent), AgentTool(agent=fundamental_agent), AgentTool(agent=technical_agent)],
        instruction=(
            "Synthesize the reports from your analysts. "
            "Provide a clear Buy/Hold/Sell recommendation with reasoning."
        ),
    )
    return AdkApp(agent=root_agent)


async def main() -> None:
    app = get_agent()

    # Serialize the agent application using cloudpickle
    with open(file_path, "wb") as fh:
        cloudpickle.dump(app, fh)

    # Collect text fragments from streaming events so we can print the
    # final LLM response once the stream completes.
    collected_parts: list[str] = []
    async for event in app.async_stream_query(user_id="USER_ID", message="Analyze $TSLA for me."):
        try:
            if not isinstance(event, dict):
                continue

            content = event.get("content") or event.get("message")
            if not isinstance(content, dict):
                continue

            parts = content.get("parts") or []
            for part in parts:
                if not isinstance(part, dict):
                    continue

                # Plain text part
                if part.get("text"):
                    collected_parts.append(part.get("text"))
                    continue

                # Function response part (may contain nested 'response' with 'result')
                if "function_response" in part:
                    fr = part.get("function_response", {})
                    resp = fr.get("response") or fr.get("result")
                    if isinstance(resp, dict):
                        result_text = resp.get("result") or resp.get("response") or ""
                        if result_text:
                            collected_parts.append(result_text)
                    elif isinstance(resp, str) and resp:
                        collected_parts.append(resp)
                    continue

                # Fallback: function_call args (stringify)
                if "function_call" in part:
                    fc = part.get("function_call", {})
                    args = fc.get("args")
                    if args:
                        collected_parts.append(str(args))
        except Exception as exc:  # pragma: no cover - defensive
            print("Error extracting text from event:", exc)

    # After streaming completes, print the aggregated LLM response
    final_response = "\n".join(p for p in collected_parts if p).strip()
    print("\nFinal LLM response:\n")
    print(final_response)


if __name__ == "__main__":
    asyncio.run(main())
