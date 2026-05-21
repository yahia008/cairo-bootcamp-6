# StarkNet MCP Transfer Agent

An autonomous multi-step agent workflow built on StarkNet-agentic for intelligent, condition-based token transfers with monitoring and alerting.

## Objective

Build a composable autonomous transfer agent using an MCP (Model Context Protocol) server architecture that can:

- Fetch wallet balances
- Validate transfer conditions
- Execute conditional transfers
- Chain multiple agent calls
- Log execution results
- Trigger alerts on low balance

## Architecture

The workflow follows this sequence:

1. Fetch balance
2. Validate transfer conditions
3. Execute transfer
4. Call another agent if needed
5. Log the result
6. Trigger an alert when balances are low

## Components

### MCP Server Structure

```typescript
const server = new McpServer({
  name: "starknet-transfer-agent",
  version: "1.0.0"
});
```

### Available Tools

| Tool | Description | Parameters |
| --- | --- | --- |
| `fetch_balance` | Get wallet balance | `wallet_address` |
| `validate_transfer` | Check transfer conditions | `amount`, `balance`, `threshold` |
| `execute_transfer` | Perform token transfer | `to`, `amount`, `token_address` |
| `call_agent` | Invoke another agent | `agent_name`, `params` |
| `log_result` | Record execution results | `status`, `details`, `timestamp` |
| `check_threshold` | Monitor balance threshold | `balance`, `threshold` |
| `trigger_alert` | Send a low-balance notification | `wallet`, `current_balance` |
