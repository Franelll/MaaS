// ============================================================================
// MaaS Platform - Main API Application
// NestJS-based REST API
// ============================================================================

import { NestFactory } from '@nestjs/core';
import { ValidationPipe, VersioningType } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';
import helmet from 'helmet';
import compression from 'compression';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log', 'debug'],
  });

  // Security
  app.use(helmet());
  app.use(compression());

  // CORS
  app.enableCors({
    origin: process.env.CORS_ORIGIN || '*',
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
  });

  // API Versioning
  app.enableVersioning({
    type: VersioningType.URI,
    defaultVersion: '1',
    prefix: 'api/v',
  });

  // Global validation pipe
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: {
        enableImplicitConversion: true,
      },
    }),
  );

  // Swagger documentation
  const config = new DocumentBuilder()
    .setTitle('MaaS Platform API')
    .setDescription('Mobility as a Service Platform API Documentation')
    .setVersion('1.0')
    .addBearerAuth()
    .addTag('map', 'Map and location-based queries')
    .addTag('vehicles', 'Vehicle and micromobility endpoints')
    .addTag('transit', 'Public transit GTFS endpoints')
    .addTag('trips', 'Trip planning and history')
    .addTag('providers', 'Mobility provider management')
    .build();

  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('docs', app, document);

  // Start server
  const port = process.env.PORT || 3000;
  await app.listen(port);

  console.log(`
  ╔═══════════════════════════════════════════════════════════════╗
  ║                                                               ║
  ║     MaaS Platform API Server                                  ║
  ║                                                               ║
  ║     🚀 Server running on: http://localhost:${port}              ║
  ║     📚 API Docs: http://localhost:${port}/docs                  ║
  ║     🏥 Health: http://localhost:${port}/health                  ║
  ║                                                               ║
  ╚═══════════════════════════════════════════════════════════════╝
  `);
}

bootstrap().catch((err) => {
  console.error('Failed to start application:', err);
  process.exit(1);
});
