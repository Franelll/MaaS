FROM node:20-alpine AS development

WORKDIR /app

RUN apk add --no-cache libc6-compat

COPY package.json package-lock.json tsconfig.base.json ./

# Copy lib/app packages
COPY apps/api/package.json ./apps/api/
COPY apps/realtime/package.json ./apps/realtime/
COPY libs/common/package.json ./libs/common/
COPY libs/cache/package.json ./libs/cache/
COPY libs/gbfs/package.json ./libs/gbfs/

RUN npm install

COPY . .

CMD ["npm", "run", "dev:realtime"]
