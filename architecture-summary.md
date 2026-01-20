# Week 2 Architecture Summary - AI Digital Twin (Converted)

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 15+ with React, Tailwind CSS v4, TypeScript |
| Backend | **Node.js 20.x + TypeScript + Express** |
| Lambda Handler | Native AWS Lambda handler |
| IaC | **AWS CloudFormation** |
| AI Service | AWS Bedrock (Nova models) |
| Deployment | GitHub Actions with OIDC |

---

## Architecture Text Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER'S BROWSER                                  │
│                         (React Chat Component)                               │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │ HTTPS
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFRONT DISTRIBUTION                              │
│                    (CDN + HTTPS + Global Edge Caching)                       │
│                     Domain: d[random].cloudfront.net                         │
└────────────────────┬────────────────────────────┬───────────────────────────┘
                     │                            │
        Static Files │                            │ API Requests
                     ▼                            ▼
┌────────────────────────────────┐  ┌────────────────────────────────────────┐
│     S3 FRONTEND BUCKET         │  │         API GATEWAY (HTTP API)         │
│  twin-{env}-frontend-{acct}    │  │                                        │
│                                │  │  Routes:                               │
│  Contents:                     │  │  - GET  /           → Lambda           │
│  - index.html                  │  │  - GET  /health     → Lambda           │
│  - _next/* (JS/CSS bundles)    │  │  - POST /chat       → Lambda           │
│  - Static assets               │  │  - GET  /conversation/{id} → Lambda    │
│                                │  │  - OPTIONS /{proxy+} (CORS)            │
│  Static Website Hosting: ON    │  │                                        │
└────────────────────────────────┘  └──────────────────┬─────────────────────┘
                                                       │ AWS_PROXY Integration
                                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LAMBDA FUNCTION                                    │
│                    Runtime: Node.js 20.x | Handler: index.handler            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      Node.js + TypeScript                            │    │
│  │                                                                      │    │
│  │  Files:                                                              │    │
│  │  - src/index.ts       → Lambda handler, routing, CORS               │    │
│  │  - src/server.ts      → Express app (local dev)                     │    │
│  │  - src/services/                                                     │    │
│  │    - bedrock.ts       → AWS Bedrock integration                     │    │
│  │    - memory.ts        → S3 conversation storage                     │    │
│  │    - context.ts       → System prompt builder                       │    │
│  │  - src/routes/                                                       │    │
│  │    - chat.ts          → POST /chat handler                          │    │
│  │    - health.ts        → GET / and /health handlers                  │    │
│  │    - conversation.ts  → GET /conversation/:id handler               │    │
│  │                                                                      │    │
│  │  Environment Variables:                                              │    │
│  │  - CORS_ORIGINS, S3_BUCKET, USE_S3, BEDROCK_MODEL_ID                │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  IAM Role Permissions:                                                       │
│  - AWSLambdaBasicExecutionRole (CloudWatch Logs)                            │
│  - AmazonBedrockFullAccess (AI API)                                         │
│  - S3 Read/Write (Memory bucket only)                                       │
└─────────────────────┬───────────────────────────┬───────────────────────────┘
                      │                           │
                      ▼                           ▼
┌────────────────────────────────┐  ┌────────────────────────────────────────┐
│     S3 MEMORY BUCKET           │  │            AWS BEDROCK                  │
│  twin-{env}-memory-{acct}      │  │                                        │
│                                │  │  Models Available:                     │
│  Contents:                     │  │  - amazon.nova-micro-v1:0 (fast)       │
│  - {session_id}.json           │  │  - amazon.nova-lite-v1:0 (balanced)    │
│                                │  │  - amazon.nova-pro-v1:0 (capable)      │
│  Format:                       │  │                                        │
│  [                             │  │  API: Converse API                     │
│    {"role": "user",            │  │  Config:                               │
│     "content": "...",          │  │  - maxTokens: 2000                     │
│     "timestamp": "..."},       │  │  - temperature: 0.7                    │
│    {"role": "assistant",       │  │  - topP: 0.9                           │
│     "content": "..."}          │  │                                        │
│  ]                             │  │                                        │
└────────────────────────────────┘  └────────────────────────────────────────┘
```

---

## Data Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────┐
│                           CHAT REQUEST FLOW                               │
└──────────────────────────────────────────────────────────────────────────┘

  User types message
         │
         ▼
┌─────────────────┐    POST /chat          ┌─────────────────┐
│   twin.tsx      │ ───────────────────▶   │   API Gateway   │
│   (Frontend)    │    {message,           │                 │
│                 │     session_id?}       │                 │
└─────────────────┘                        └────────┬────────┘
                                                    │
                                                    ▼
                                           ┌─────────────────┐
                                           │     Lambda      │
                                           │   (index.ts)    │
                                           └────────┬────────┘
                                                    │
                    ┌───────────────────────────────┼───────────────────────┐
                    │                               │                       │
                    ▼                               ▼                       ▼
           ┌─────────────────┐            ┌─────────────────┐      ┌─────────────────┐
           │  memory.ts      │            │   context.ts    │      │  bedrock.ts     │
           │  Load history   │            │   Build prompt  │      │  Call Converse  │
           │  from S3        │            │   with persona  │      │  API            │
           └────────┬────────┘            └────────┬────────┘      └────────┬────────┘
                    │                               │                       │
                    └───────────────────────────────┼───────────────────────┘
                                                    │
                                                    ▼
                                           ┌─────────────────┐
                                           │   AWS Bedrock   │
                                           │   (Nova Model)  │
                                           │                 │
                                           │   Input:        │
                                           │   - System msg  │
                                           │   - History     │
                                           │   - User msg    │
                                           └────────┬────────┘
                                                    │
                                                    ▼
                                           ┌─────────────────┐
                                           │  memory.ts      │
                                           │  Save to S3     │
                                           └────────┬────────┘
                                                    │
                                                    ▼
┌─────────────────┐    {response,          ┌─────────────────┐
│   twin.tsx      │ ◀──────────────────    │     Lambda      │
│   Display msg   │     session_id}        │   Return JSON   │
└─────────────────┘                        └─────────────────┘
```

---

## CI/CD Pipeline Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            GITHUB ACTIONS CI/CD                              │
└─────────────────────────────────────────────────────────────────────────────┘

  Developer pushes to main
         │
         ▼
┌─────────────────┐
│  GitHub Repo    │
│  (main branch)  │
└────────┬────────┘
         │ Triggers workflow
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         deploy.yml Workflow                                  │
│                                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                      │
│  │  Checkout   │───▶│ Setup OIDC  │───▶│ Setup       │                      │
│  │  Code       │    │ AWS Creds   │    │ Node.js 20  │                      │
│  └─────────────┘    └─────────────┘    └─────────────┘                      │
│                                               │                              │
│                     ┌─────────────────────────┼─────────────────────────┐   │
│                     │                         │                         │   │
│                     ▼                         ▼                         │   │
│            ┌─────────────────┐      ┌─────────────────┐                 │   │
│            │  Build Backend  │      │  Build Frontend │                 │   │
│            │  npm run build  │      │  npm run build  │                 │   │
│            │  + zip Lambda   │      │  (static export)│                 │   │
│            └────────┬────────┘      └────────┬────────┘                 │   │
│                     │                         │                         │   │
│                     └─────────────┬───────────┘                         │   │
│                                   │                                     │   │
│                                   ▼                                     │   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    CloudFormation Deploy                             │   │
│  │                                                                      │   │
│  │   1. Create/Update stack (main.yaml)                                │   │
│  │   2. Upload Lambda code to function                                 │   │
│  │   3. Sync frontend to S3                                            │   │
│  │   4. Invalidate CloudFront cache                                    │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              AWS Resources Updated                           │
│                                                                              │
│   Lambda ←── New Node.js code deployed                                      │
│   S3 ←── New frontend files synced                                          │
│   CloudFront ←── Cache invalidated                                          │
│   API Gateway ←── Routes configured                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Infrastructure Components (CloudFormation)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       CLOUDFORMATION RESOURCES                               │
│                           (main.yaml)                                        │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  NETWORKING & CDN                                                            │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  AWS::CloudFront::Distribution                                       │    │
│  │  - Origin: S3 frontend bucket (HTTP only)                           │    │
│  │  - Viewer Protocol: Redirect HTTP to HTTPS                          │    │
│  │  - Cache Policy: CachingOptimized                                   │    │
│  │  - Error Pages: 404/403 → index.html (SPA routing)                  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  COMPUTE                                                                     │
│  ┌────────────────────────────┐    ┌────────────────────────────────────┐   │
│  │  AWS::Lambda::Function     │    │  AWS::ApiGatewayV2::Api            │   │
│  │  - Runtime: nodejs20.x     │◀───│  - Protocol: HTTP                  │   │
│  │  - Memory: 512 MB (conf.)  │    │  - Integration: AWS_PROXY          │   │
│  │  - Timeout: 30s (conf.)    │    │  - CORS: Configured                │   │
│  │  - Handler: index.handler  │    │  - Auto-deploy: Enabled            │   │
│  └────────────────────────────┘    └────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  STORAGE                                                                     │
│  ┌────────────────────────────┐    ┌────────────────────────────────────┐   │
│  │  AWS::S3::Bucket           │    │  AWS::S3::Bucket                   │   │
│  │  (Frontend)                │    │  (Memory)                          │   │
│  │  - Static website hosting  │    │  - Private access only             │   │
│  │  - Public read policy      │    │  - Versioning enabled              │   │
│  │  - Index: index.html       │    │  - Lambda read/write               │   │
│  └────────────────────────────┘    └────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│  SECURITY                                                                    │
│  ┌────────────────────────────┐    ┌────────────────────────────────────┐   │
│  │  AWS::IAM::Role            │    │  AWS::IAM::OIDCProvider            │   │
│  │  (Lambda Execution)        │    │  (GitHub Actions)                  │   │
│  │  - CloudWatch Logs         │    │  - Federated identity              │   │
│  │  - Bedrock full access     │    │  - Temporary credentials           │   │
│  │  - S3 memory bucket only   │    │  - Repository-scoped               │   │
│  └────────────────────────────┘    └────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## API Endpoints Reference

| Method | Endpoint | Description | Request Body | Response |
|--------|----------|-------------|--------------|----------|
| GET | `/` | Root endpoint | - | `{"message": "AI Digital Twin API...", "ai_model": "..."}` |
| GET | `/health` | Health check | - | `{"status": "healthy", "use_s3": bool, "bedrock_model": string}` |
| POST | `/chat` | Send message | `{"message": string, "session_id"?: string}` | `{"response": string, "session_id": string}` |
| GET | `/conversation/{sessionId}` | Get history | - | `{"session_id": string, "messages": array}` |

---

## Environment Variables

### Backend (Lambda)

| Variable | Description | Example |
|----------|-------------|---------|
| `CORS_ORIGINS` | Allowed origins for CORS | `https://d123.cloudfront.net` |
| `S3_BUCKET` | Memory bucket name | `twin-dev-memory-123456` |
| `USE_S3` | Enable S3 storage | `true` |
| `BEDROCK_MODEL_ID` | AI model to use | `amazon.nova-lite-v1:0` |
| `DEFAULT_AWS_REGION` | AWS region | `us-east-1` |

### Frontend

| Variable | Description | Example |
|----------|-------------|---------|
| `NEXT_PUBLIC_API_URL` | API endpoint | `https://abc.execute-api.us-east-1.amazonaws.com` |

---

## Project File Structure

```
week2-conversion/
├── backend/                         # Node.js + TypeScript
│   ├── src/
│   │   ├── index.ts                 # Lambda handler
│   │   ├── server.ts                # Express (local dev)
│   │   ├── types/index.ts           # TypeScript interfaces
│   │   ├── utils/config.ts          # Environment config
│   │   ├── routes/
│   │   │   ├── chat.ts
│   │   │   ├── health.ts
│   │   │   └── conversation.ts
│   │   └── services/
│   │       ├── bedrock.ts           # AWS Bedrock client
│   │       ├── memory.ts            # S3 storage
│   │       └── context.ts           # Prompt builder
│   ├── data/                        # Persona files
│   ├── package.json
│   └── tsconfig.json
│
├── frontend/                        # Next.js + TypeScript
│   ├── app/
│   │   ├── page.tsx
│   │   ├── layout.tsx
│   │   └── globals.css
│   ├── components/
│   │   └── twin.tsx                 # Chat component
│   ├── package.json
│   └── next.config.ts
│
├── cloudformation/                  # AWS CloudFormation
│   ├── main.yaml                    # Infrastructure
│   ├── github-oidc.yaml             # CI/CD auth
│   └── parameters/
│       ├── dev.json
│       ├── test.json
│       └── prod.json
│
├── scripts/
│   ├── deploy.sh / deploy.ps1
│   └── destroy.sh / destroy.ps1
│
└── .github/workflows/
    ├── deploy.yml
    └── destroy.yml
```

---

## Deployment Commands

### Local Development

```bash
# Backend
cd backend && npm install && npm run dev

# Frontend (separate terminal)
cd frontend && npm install && npm run dev
```

### Deploy to AWS

```bash
# Mac/Linux
./scripts/deploy.sh dev      # Deploy to dev
./scripts/deploy.sh prod     # Deploy to prod

# Windows
.\scripts\deploy.ps1 dev
.\scripts\deploy.ps1 prod
```

### Destroy Environment

```bash
# Mac/Linux
./scripts/destroy.sh dev

# Windows
.\scripts\destroy.ps1 dev
```

---

## CloudFormation Stack Outputs

| Output | Description |
|--------|-------------|
| `FrontendBucketName` | S3 bucket for static files |
| `MemoryBucketName` | S3 bucket for conversations |
| `LambdaFunctionName` | Lambda function name |
| `LambdaFunctionArn` | Lambda function ARN |
| `ApiGatewayUrl` | API Gateway endpoint |
| `CloudFrontUrl` | CloudFront distribution URL |
| `CloudFrontDistributionId` | CloudFront ID (for invalidations) |
