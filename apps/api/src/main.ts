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

  // CORS - Allow Flutter Web (localhost:8080)
  app.enableCors({
    origin: [
      'http://localhost:8080',
      'http://localhost:3000',
      'http://127.0.0.1:8080',
      ...(process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',') : []),
    ],
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE,OPTIONS',
    credentials: true,
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
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
