# Conversion Plan: Week 2 to New Stack

## Overview

Converting the AI Digital Twin project from:
- **Backend**: Python FastAPI → **Node.js + TypeScript**
- **IaC**: Terraform → **CloudFormation**
- **Frontend**: Next.js + TypeScript (keep as-is)

---

## Target Folder Structure

```
week2-conversion/
├── architecture-summary.md          # Architecture documentation
├── conversion-plan.md               # This file
├── frontend/                        # Next.js + TypeScript (mostly unchanged)
│   ├── app/
│   │   ├── page.tsx
│   │   ├── layout.tsx
│   │   └── globals.css
│   ├── components/
│   │   └── twin.tsx
│   ├── package.json
│   ├── tsconfig.json
│   ├── next.config.ts
│   └── tailwind.config.ts
├── backend/                         # Node.js + TypeScript (NEW)
│   ├── src/
│   │   ├── index.ts                 # Lambda handler entry point
│   │   ├── server.ts                # Express/Fastify app
│   │   ├── routes/
│   │   │   ├── chat.ts              # POST /chat
│   │   │   ├── health.ts            # GET /health
│   │   │   └── conversation.ts      # GET /conversation/:id
│   │   ├── services/
│   │   │   ├── bedrock.ts           # AWS Bedrock integration
│   │   │   ├── memory.ts            # S3 conversation storage
│   │   │   └── context.ts           # System prompt builder
│   │   ├── types/
│   │   │   └── index.ts             # TypeScript interfaces
│   │   └── utils/
│   │       └── config.ts            # Environment config
│   ├── data/                        # Persona data files
│   │   ├── facts.json
│   │   ├── summary.txt
│   │   ├── style.txt
│   │   └── me.txt
│   ├── package.json
│   ├── tsconfig.json
│   └── esbuild.config.js            # Build config for Lambda
├── cloudformation/                  # CloudFormation templates (NEW)
│   ├── main.yaml                    # Main stack (all resources)
│   ├── github-oidc.yaml             # GitHub OIDC provider
│   └── parameters/
│       ├── dev.json
│       ├── test.json
│       └── prod.json
├── scripts/                         # Deployment scripts
│   ├── deploy.sh
│   ├── deploy.ps1
│   ├── destroy.sh
│   └── destroy.ps1
└── .github/
    └── workflows/
        ├── deploy.yml
        └── destroy.yml
```

---

## Conversion Plan - Step by Step

### Phase 1: Backend Conversion (Python → Node.js + TypeScript)

#### Step 1.1: Initialize Node.js Project
- Create `backend/` folder structure
- Initialize `package.json` with dependencies:
  - `@aws-sdk/client-bedrock-runtime` - Bedrock API
  - `@aws-sdk/client-s3` - S3 operations
  - `express` or `fastify` - Web framework
  - `@types/*` - TypeScript types
  - `esbuild` - Bundle for Lambda
  - `uuid` - Session ID generation

#### Step 1.2: Convert server.py → server.ts
- Port FastAPI routes to Express/Fastify
- Implement CORS middleware
- Create route handlers:
  - `GET /` - Root endpoint
  - `GET /health` - Health check
  - `POST /chat` - Chat handler
  - `GET /conversation/:sessionId` - Get history

#### Step 1.3: Convert context.py → context.ts
- Port system prompt builder
- Load persona data files (facts.json, summary.txt, etc.)
- Build message context with conversation history

#### Step 1.4: Convert resources.py → services/
- Create `bedrock.ts` - Bedrock client and converse API
- Create `memory.ts` - S3 read/write for conversation history
- Create `config.ts` - Environment variable handling

#### Step 1.5: Create Lambda Handler
- Create `index.ts` as Lambda entry point
- Use `aws-lambda` types
- Handle API Gateway proxy events
- Return properly formatted responses

#### Step 1.6: Build Configuration
- Create `esbuild.config.js` for bundling
- Configure TypeScript compilation
- Create build script for Lambda deployment package

---

### Phase 2: Infrastructure Conversion (Terraform → CloudFormation)

#### Step 2.1: Create Main CloudFormation Template
Convert Terraform resources to CloudFormation:

| Terraform Resource | CloudFormation Resource |
|-------------------|------------------------|
| `aws_lambda_function` | `AWS::Lambda::Function` |
| `aws_api_gateway_api` | `AWS::ApiGatewayV2::Api` |
| `aws_api_gateway_stage` | `AWS::ApiGatewayV2::Stage` |
| `aws_api_gateway_integration` | `AWS::ApiGatewayV2::Integration` |
| `aws_api_gateway_route` | `AWS::ApiGatewayV2::Route` |
| `aws_s3_bucket` (frontend) | `AWS::S3::Bucket` |
| `aws_s3_bucket` (memory) | `AWS::S3::Bucket` |
| `aws_cloudfront_distribution` | `AWS::CloudFront::Distribution` |
| `aws_iam_role` | `AWS::IAM::Role` |
| `aws_iam_policy` | `AWS::IAM::Policy` |

#### Step 2.2: Create Parameter Files
- `parameters/dev.json` - Development environment
- `parameters/test.json` - Test environment
- `parameters/prod.json` - Production environment

#### Step 2.3: Create GitHub OIDC Template
- `github-oidc.yaml` - OIDC provider for GitHub Actions
- IAM role with trust policy for GitHub
- Required permissions for deployment

#### Step 2.4: CloudFormation Outputs
Define outputs for:
- API Gateway URL
- CloudFront Distribution URL
- S3 Bucket names
- Lambda Function ARN

---

### Phase 3: Deployment Scripts Update

#### Step 3.1: Update deploy.sh / deploy.ps1
- Replace Terraform commands with CloudFormation CLI
- Update build steps for Node.js:
  - `npm install` instead of `pip install`
  - `npm run build` for TypeScript compilation
  - `esbuild` bundle instead of Python zip
- Use `aws cloudformation deploy` command

#### Step 3.2: Update destroy.sh / destroy.ps1
- Empty S3 buckets before deletion
- Use `aws cloudformation delete-stack`
- Wait for stack deletion completion

---

### Phase 4: CI/CD Updates (GitHub Actions)

#### Step 4.1: Update deploy.yml
```yaml
Changes needed:
- Remove: Setup Python step
- Update: Node.js version to 20
- Update: Build commands for TypeScript
- Update: Use CloudFormation instead of Terraform
```

#### Step 4.2: Update destroy.yml
```yaml
Changes needed:
- Update: Use CloudFormation delete-stack
- Update: S3 bucket emptying commands
```

---

### Phase 5: Frontend Adjustments

#### Step 5.1: Verify API Compatibility
- Ensure API response format matches
- Test all endpoints work with Node.js backend
- Verify CORS configuration

#### Step 5.2: Update Environment Variables
- `NEXT_PUBLIC_API_URL` - Points to new API Gateway

---

## Key File Mappings

### Backend Files

| Python (Current) | TypeScript (Target) |
|-----------------|---------------------|
| `server.py` | `src/server.ts` |
| `context.py` | `src/services/context.ts` |
| `resources.py` | `src/services/bedrock.ts` + `memory.ts` |
| `lambda_handler.py` | `src/index.ts` |
| `requirements.txt` | `package.json` |

### Infrastructure Files

| Terraform (Current) | CloudFormation (Target) |
|--------------------|------------------------|
| `main.tf` | `cloudformation/main.yaml` |
| `variables.tf` | Parameters in `main.yaml` |
| `outputs.tf` | Outputs in `main.yaml` |
| `terraform.tfvars` | `parameters/*.json` |
| `backend.tf` | Not needed (AWS manages state) |

---

## Dependencies for New Stack

### Backend (package.json)
```json
{
  "dependencies": {
    "@aws-sdk/client-bedrock-runtime": "^3.x",
    "@aws-sdk/client-s3": "^3.x",
    "express": "^4.x",
    "cors": "^2.x",
    "uuid": "^9.x"
  },
  "devDependencies": {
    "@types/node": "^20.x",
    "@types/express": "^4.x",
    "@types/cors": "^2.x",
    "@types/uuid": "^9.x",
    "@types/aws-lambda": "^8.x",
    "typescript": "^5.x",
    "esbuild": "^0.20.x"
  }
}
```

### Lambda Runtime
- Node.js 20.x (AWS Lambda supported runtime)

---

## Validation Checklist

After conversion, verify:

- [ ] Backend builds successfully with TypeScript
- [ ] Lambda deployment package is < 50MB
- [ ] All API endpoints return correct responses
- [ ] Bedrock integration works (chat responses)
- [ ] S3 memory storage works (conversation persistence)
- [ ] CORS allows frontend requests
- [ ] CloudFormation stack deploys without errors
- [ ] CloudFront serves frontend correctly
- [ ] GitHub Actions workflow succeeds
- [ ] Multi-environment deployment works (dev/test/prod)

---

## Estimated Work Breakdown

| Phase | Tasks |
|-------|-------|
| Phase 1 | Backend conversion (6 steps) |
| Phase 2 | Infrastructure conversion (4 steps) |
| Phase 3 | Deployment scripts (2 steps) |
| Phase 4 | CI/CD updates (2 steps) |
| Phase 5 | Frontend verification (2 steps) |

**Total: 16 implementation steps**

---

## Next Steps

1. Start with Phase 1.1 - Initialize Node.js backend project
2. Convert backend files one by one
3. Test locally before moving to infrastructure
4. Convert CloudFormation templates
5. Update deployment scripts
6. Test full deployment pipeline
