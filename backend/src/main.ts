import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import compression from 'compression';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  // Every JSON payload above 1KB is gzipped. A hotel search response is
  // ~140KB raw and ~15KB compressed — the single cheapest win on mobile data.
  app.use(compression({ threshold: 1024 }));
  app.enableCors({
    origin: process.env.ALLOWED_ORIGINS
      ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim())
      : ['http://localhost:3000'],
    credentials: true,
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  const port = process.env.PORT ?? 3000;
  // Bind to all interfaces so the Android device can connect
  const host = process.env.HOST ?? '0.0.0.0';
  await app.listen(port, host);
  // eslint-disable-next-line no-console
  console.log(`TokiGo Backend listening on http://0.0.0.0:${port}`);
}
bootstrap();