"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ListMemoryQueryDto = exports.UpdateMemoryDto = exports.CreateMemoryDto = exports.MEMORY_SOURCES = exports.MEMORY_TYPES = void 0;
exports.containsSensitiveData = containsSensitiveData;
exports.containsControlCharacters = containsControlCharacters;
const class_validator_1 = require("class-validator");
/**
 * Memory DTOs (Phase 2A — Foundation).
 *
 * The memory spine stores STRUCTURED FACTS only: `key → value` with a
 * provenance source and a validated confidence. Full conversation
 * transcripts and any sensitive material are rejected BEFORE persistence —
 * `containsSensitiveData()` performs a recursive scan of the value tree so a
 * forbidden key cannot hide at any nesting depth.
 */
/** All memory categories the spine understands. */
exports.MEMORY_TYPES = [
    'preference',
    'behavior',
    'conversation',
    'derived',
];
/** All provenance sources a memory record can carry. */
exports.MEMORY_SOURCES = [
    'user_explicit',
    'behavior_event',
    'ai_conversation',
    'system_derived',
];
/**
 * Keys that must NEVER be persisted in a memory value — at any depth.
 * Covers credentials, payment material, and precise location (country-level
 * geo is fine; coordinates are not).
 */
const SENSITIVE_KEY_FRAGMENTS = [
    'password',
    'passwd',
    'token',
    'secret',
    'credential',
    'authorization',
    'card',
    'payment',
    'cvv',
    'latitude',
    'longitude',
    'accesstoken',
    'refreshtoken',
];
function containsSensitiveData(value) {
    return _scan(value);
}
/**
 * Phase 2D — string values stored in the memory spine must be SINGLE-LINE.
 * CR/LF and other control characters would let a stored fact forge new
 * lines when it is later rendered into the AI context block (memory values
 * are untrusted user-derived DATA, never instructions). Applies to every
 * string at any depth of the value tree — same recursion as the sensitive
 * scanner.
 */
function containsControlCharacters(value) {
    return _scanStrings(value, (s) => /[\u0000-\u001f\u007f]/.test(s));
}
function _scanStrings(node, predicate) {
    if (node === null || node === undefined)
        return false;
    if (typeof node === 'string')
        return predicate(node);
    if (Array.isArray(node)) {
        return node.some((entry) => _scanStrings(entry, predicate));
    }
    if (typeof node === 'object') {
        for (const child of Object.values(node)) {
            if (_scanStrings(child, predicate))
                return true;
        }
    }
    return false;
}
function _scan(node) {
    if (node === null || node === undefined)
        return false;
    if (Array.isArray(node))
        return node.some((entry) => _scan(entry));
    if (typeof node === 'object') {
        for (const [key, child] of Object.entries(node)) {
            const normalized = key.toLowerCase().replace(/[^a-z]/g, '');
            if (SENSITIVE_KEY_FRAGMENTS.some((frag) => normalized.includes(frag))) {
                return true;
            }
            if (_scan(child))
                return true;
        }
    }
    return false;
}
class CreateMemoryDto {
    type;
    key;
    /** Structured fact value (object) or a scalar fact. */
    value;
    source;
    confidence;
    expiresAt;
}
exports.CreateMemoryDto = CreateMemoryDto;
__decorate([
    (0, class_validator_1.IsIn)(exports.MEMORY_TYPES),
    __metadata("design:type", String)
], CreateMemoryDto.prototype, "type", void 0);
__decorate([
    (0, class_validator_1.IsString)(),
    (0, class_validator_1.Length)(1, 120),
    __metadata("design:type", String)
], CreateMemoryDto.prototype, "key", void 0);
__decorate([
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], CreateMemoryDto.prototype, "value", void 0);
__decorate([
    (0, class_validator_1.IsIn)(exports.MEMORY_SOURCES),
    __metadata("design:type", String)
], CreateMemoryDto.prototype, "source", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(1),
    __metadata("design:type", Number)
], CreateMemoryDto.prototype, "confidence", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], CreateMemoryDto.prototype, "expiresAt", void 0);
class UpdateMemoryDto {
    /** Value/source/confidence/expiresAt only — `type` and `key` are the
     * record's identity and are immutable through update (the upsert path is
     * the only way to "change" them, by rewriting the same logical fact). */
    value;
    source;
    confidence;
    expiresAt;
}
exports.UpdateMemoryDto = UpdateMemoryDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsObject)(),
    __metadata("design:type", Object)
], UpdateMemoryDto.prototype, "value", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.MEMORY_SOURCES),
    __metadata("design:type", String)
], UpdateMemoryDto.prototype, "source", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsNumber)(),
    (0, class_validator_1.Min)(0),
    (0, class_validator_1.Max)(1),
    __metadata("design:type", Number)
], UpdateMemoryDto.prototype, "confidence", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsDateString)(),
    __metadata("design:type", String)
], UpdateMemoryDto.prototype, "expiresAt", void 0);
class ListMemoryQueryDto {
    type;
    source;
    /** When true, expired records are included in the listing (the default
     * hides them; documented + tested Phase 2A behaviour). */
    includeExpired;
}
exports.ListMemoryQueryDto = ListMemoryQueryDto;
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.MEMORY_TYPES),
    __metadata("design:type", String)
], ListMemoryQueryDto.prototype, "type", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsIn)(exports.MEMORY_SOURCES),
    __metadata("design:type", String)
], ListMemoryQueryDto.prototype, "source", void 0);
__decorate([
    (0, class_validator_1.IsOptional)(),
    (0, class_validator_1.IsBoolean)(),
    __metadata("design:type", Boolean)
], ListMemoryQueryDto.prototype, "includeExpired", void 0);
//# sourceMappingURL=memory.dto.js.map