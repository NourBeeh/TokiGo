import { Module } from '@nestjs/common';
import { NuiteeService } from './nuitee.service';
import { NuiteeFlightService } from './nuitee.flight.service';

@Module({
  providers: [NuiteeService, NuiteeFlightService],
  exports: [NuiteeService, NuiteeFlightService],
})
export class NuiteeModule {}
