#ifdef GL_ES
    precision mediump float;
#endif

varying vec2 v_texCoord;
uniform sampler2D CC_Texture0;

uniform vec2 _robHack;
uniform vec2 _camRot;

// ---------------------
// COMMON
// ---------------------
uniform vec2 _textureScale;
uniform vec2 _textureScaleInv;

// ---------------------
// SHOCKWAVE
// ---------------------
uniform float _shockWaveTime;
uniform float _shockWaveTime1;
uniform float _shockWaveTime2;
uniform float _shockWaveTime3;
uniform float _shockWaveTime4;
uniform float _shockWaveStrength;
uniform float _shockWaveWaves;
uniform vec2 _shockWaveCenter;
uniform bool _shockWaveInvert;
uniform float _shockWaveMinSize;
uniform float _shockWaveMaxSize;
uniform float _shockWaveMaxDistVal;

// ---------------------
// SHOCKLINE
// ---------------------
uniform float _shockLineTime;
uniform float _shockLineTime1;
uniform float _shockLineTime2;
uniform float _shockLineTime3;
uniform float _shockLineTime4;
uniform bool _shockLineAxis;
uniform bool _shockLineDirection;
uniform bool _shockLineDual;
uniform float _shockLineWaves;
uniform vec2 _shockLineStrength;
uniform float _shockLineCenter;
uniform float _shockLineMaxDistVal;

// ---------------------
// GLITCH
// ---------------------
uniform float _glitchBot;
uniform float _glitchTop;
uniform float _glitchXOffset;
uniform vec2 _glitchColOffset;
uniform float _glitchRnd;

// ---------------------
// CHROMATIC
// ---------------------
uniform float _chromaticXOff;
uniform float _chromaticYOff;

// ---------------------
// LENSCIRCLE
// ---------------------
uniform vec2 _lensCircleOrigin;
uniform float _lensCircleStart;
uniform float _lensCircleEnd;
uniform float _lensCircleStrength;
uniform vec3 _lensCircleTint;
uniform bool _lensCircleAdditive;

// ---------------------
// BULGE
// ---------------------
uniform vec2 _bulgeOrigin;
uniform float _bulgeValue;
uniform float _bulgeValue2;
uniform float _bulgeRadius;

// ---------------------
// PINCH
// ---------------------
uniform vec2 _pinchCenterPos;
uniform vec2 _pinchValue;
uniform vec2 _pinchCalc1;
uniform float _pinchRadius;

// ---------------------
// BLUR COMMON
// ---------------------
uniform bool _blurUseRef;
uniform vec3 _blurRefColor;
uniform float _blurIntensity;
uniform float _blurFade;
uniform bool _blurOnlyEmpty;

// ---------------------
// RADIALBLUR
// ---------------------
uniform vec2 _radialBlurCenter;
uniform float _radialBlurValue;

#define radialBlurSamples 10
#define radialBlurSamplesInv 0.1

// ---------------------
// MOTIONBLUR
// ---------------------
uniform vec2 _motionBlurValue;
uniform float _motionBlurMult;
uniform bool _motionBlurDual;

#define mbSamples 9.0
#define mbSamplesLoop 9.0
const float mbSamplesInv = 1.0/mbSamples;

#define mbSamplesDual 9.0
#define mbSamplesLoopDual 5.0
const float mbSamplesDualInv = 1.0/mbSamplesDual;

// ---------------------
// CHROMATICGLITCH
// ---------------------
uniform float _cGTime;
uniform float _cGRGBOffset; // 1.0
uniform float _cGYOffset;
uniform float _cGStrength; // 0.02
uniform float _cGHeight;
uniform float _cGLineStrength;
uniform float _cGLineThick;

// ---------------------
// SEPIA
// ---------------------
uniform float _sepiaValue;
const mat4 sepiaMat = mat4(0.393, 0.769, 0.189, 0.0, 0.349, 0.686, 0.168, 0.0, 0.272, 0.534, 0.131, 0.0, 0,0,0,0);

// ---------------------
// INVERT
// ---------------------
uniform vec4 _invertColorValue;

// ---------------------
// GRAYSCALE
// ---------------------
uniform float _grayscaleValue;
uniform vec3 _grayscaleTint;
uniform bool _grayscaleUseLum;

// ---------------------
// HUESHIFT
// ---------------------
uniform float _hueShiftCosA;
uniform float _hueShiftSinA;

// ---------------------
// COLORCHANGE
// ---------------------
uniform vec3 _colorChangeC;
uniform vec3 _colorChangeB;

const vec3 _hueShiftK = vec3(0.57735, 0.57735, 0.57735);

// ---------------------
// SPLITSCREEN
// ---------------------
uniform float _rowmod;
uniform float _colmod;

uniform float _rowmodCalc;
uniform float _colmodCalc;

uniform float _splitXStart;
uniform float _splitXRange;
uniform float _splitXRangeMult;
uniform float _splitYStart;
uniform float _splitYRange;
uniform float _splitYRangeMult;

// ---------------------
// FUNCTIONS
// ---------------------

// return 1 if v inside 1d range
float insideRange(float v, float bottom, float top) {
    return step(bottom, v) - step(top, v);
}

float rand(vec2 n) {
    return fract(sin(dot(n, vec2(12.9898, 4.1414))) * 437.5854);
}

float noise(vec2 n) {
    const vec2 d = vec2(0.0, 1.0);
    vec2 b = floor(n), f = smoothstep(vec2(0.0), vec2(1.0), fract(n));
    return mix(mix(rand(b), rand(b + d.yx), f.x), mix(rand(b + d.xy), rand(b + d.yy), f.x), f.y);
}

vec2 applyRotation(vec2 uv) {
    uv -= vec2(0.5) / _robHack;
    uv = vec2(
        _camRot.x * uv.x - _camRot.y * uv.y,
        _camRot.y * uv.x + _camRot.x * uv.y
    );
    uv += vec2(0.5) / _robHack;
    return uv;
}

vec2 undoRotation(vec2 uv) {
    uv -= vec2(0.5) / _robHack;
    uv = vec2(
        _camRot.x * uv.x - -_camRot.y * uv.y,
        -_camRot.y * uv.x + _camRot.x * uv.y
    );
    uv += vec2(0.5) / _robHack;
    return uv;
}

vec4 sampleTex(vec2 uv) {
    return texture2D(CC_Texture0, undoRotation(uv) / _robHack);
}

// ---------------------
// MAIN
// ---------------------
void main()
{
    vec2 scaledTexCoord = applyRotation(v_texCoord * _robHack);
    vec2 targetVec = scaledTexCoord;

    // ---------------------
    // SHOCKWAVE
    // ---------------------
    if (_shockWaveTime > 0.0) {
        vec2 p = targetVec*_textureScaleInv - applyRotation(_shockWaveCenter);

        float dis = max(length(p), 0.0001);

        float k = _shockWaveMaxDistVal != 0.0 ? clamp(1.0 - dis * _shockWaveMaxDistVal, 0.0, 1.0) : 1.0;
        if (_shockWaveInvert) dis = _shockWaveMaxSize - max(dis, _shockWaveMinSize);

        k *= clamp(smoothstep(_shockWaveTime1, _shockWaveTime2, dis) - smoothstep(_shockWaveTime3, _shockWaveTime4, dis), 0.0, 1.0);

        // Ripples equation multiplied with ring circles so that it will be shockwave
        targetVec += k * ((p/dis) * sin(dis * _shockWaveWaves - _shockWaveTime) * _shockWaveStrength);
    }

    // ---------------------
    // SHOCKLINE
    // ---------------------
    if (_shockLineTime != 0.0) {
        //float dis = (_shockLineAxis ? targetVec.y : targetVec.x) * _textureScaleInv - applyRotation(_shockLineCenter);
        float dis = (_shockLineAxis ? targetVec.y : targetVec.x) - applyRotation(_shockLineCenter);

        float k = _shockLineMaxDistVal == 0.0 ? 1.0 : (clamp(1.0 + (dis < 0.0 ? 1.0 : -1.0) * dis * _shockLineMaxDistVal, 0.0, 1.0));

        if (_shockLineDual) dis = abs(dis);
        if (_shockLineDirection) dis = 1.0-dis;

        k *= clamp(smoothstep(_shockLineTime1, _shockLineTime2, dis) - smoothstep(_shockLineTime3, _shockLineTime4, dis), 0.0, 1.0);
        targetVec += k*sin(dis*_shockLineWaves-_shockLineTime)*_shockLineStrength;
    }


    // ---------------------
    // BULGE
    // ---------------------
    if (_bulgeValue > 0.0) {
        vec2 d = targetVec*_textureScaleInv - applyRotation(_bulgeOrigin);

        float di = length(d);

        if (di < _bulgeRadius) {
            float fadeValue = pow(di / _bulgeRadius, 3.0);
            vec2 bulgedVec = (applyRotation(_bulgeOrigin) + normalize(d) * tan(sqrt(dot(d, d)) * _bulgeValue) * _bulgeValue2) * _textureScale;
            targetVec = targetVec * fadeValue + bulgedVec * (1.0 - fadeValue);
        }
    }

    // ---------------------
    // PINCH
    // ---------------------
    // Original function
    if (_pinchValue.x != 0.0 || _pinchValue.y != 0.0) {
        vec2 d = targetVec*_textureScaleInv - applyRotation(_pinchCenterPos);

        float di = length(d);
        if (di < _pinchRadius) {
            float fadeValue = pow(di / _pinchRadius, 2.0);
            vec2 pinchedVec = (applyRotation(_pinchCenterPos) + normalize(d) * atan(sqrt(dot(d, d)) * -_pinchValue * 20.0) * _pinchCalc1) * _textureScale;
            targetVec = targetVec * fadeValue + pinchedVec * (1.0 - fadeValue);
        }
    }

    // ---------------------
    // GLITCH
    // ---------------------
    if (_glitchTop > 0.0) {
        // Random offset slices horizontally
        targetVec.x += _glitchXOffset * insideRange(targetVec.y, _glitchBot, _glitchTop);
    }

    // ---------------------
    // SPLITSCREEN
    // ---------------------
    if (_colmod != 1.0 || _rowmod != 1.0) {
        targetVec = undoRotation(targetVec);
        float normalizedX = (targetVec.x - _splitXStart) * _splitXRangeMult;
        normalizedX = (normalizedX < 0.5*_textureScale.x) ? normalizedX * _colmod : (normalizedX * _colmod) + _colmodCalc;
        targetVec.x = _splitXStart + fract(normalizedX) * _splitXRange;

        float normalizedY = (targetVec.y - _splitYStart) * _splitYRangeMult;
        normalizedY = (normalizedY < 0.5*_textureScale.y) ? normalizedY * _rowmod : (normalizedY * _rowmod) + _rowmodCalc;
        targetVec.y = _splitYStart + fract(normalizedY) * _splitYRange;
        targetVec = applyRotation(targetVec);
    }

    // --------------------- --------------------- ---------------------
    // --------------------- --------------------- ---------------------

    // ---------------------
    // APPLY THE COLOR
    // ---------------------
    gl_FragColor = sampleTex(targetVec);

    // --------------------- --------------------- ---------------------
    // --------------------- --------------------- ---------------------

    // ---------------------
    // CHROMATICGLITCH
    // ---------------------
    if (_cGRGBOffset != 0.0) {
        float cVal = (scaledTexCoord.y+_cGYOffset)*50.0*_cGHeight;
        targetVec.x += (noise(vec2(_cGTime,cVal))-noise(vec2(0,cVal)))*_cGStrength;
        vec4 r = sampleTex(vec2(targetVec.x - _cGRGBOffset, targetVec.y));
        vec4 g = sampleTex(vec2(targetVec.x, targetVec.y));
        vec4 b = sampleTex(vec2(targetVec.x + _cGRGBOffset, targetVec.y));

        vec3 color = vec3(r.r, g.g, b.b);

        if (_cGLineThick > 0.0) {
            color -= smoothstep(_cGLineThick - 0.01, _cGLineThick + 0.01, sin((scaledTexCoord.y+_cGYOffset)*300.0*_cGHeight))*_cGLineStrength;
        }

        gl_FragColor = vec4(color, (r.a+g.a+b.a)*0.3333);
    }

    // ---------------------
    // GLITCH
    // ---------------------
    if (_glitchTop > 0.0) {
        // Offset one channel
        if (_glitchRnd < 0.33) {
            vec4 col2 = sampleTex(targetVec + _glitchColOffset);
            gl_FragColor.r = col2.r;
            gl_FragColor.a = max(gl_FragColor.a, col2.a);
        }
        else if (_glitchRnd < 0.66) {
            vec4 col2 = sampleTex(targetVec + _glitchColOffset);
            gl_FragColor.g = col2.g;
            gl_FragColor.a = max(gl_FragColor.a, col2.a);
        }
        else {
            vec4 col2 = sampleTex(targetVec + _glitchColOffset);
            gl_FragColor.b = col2.b;
            gl_FragColor.a = max(gl_FragColor.a, col2.a);
        }
    }

    // ---------------------
    // CHROMATIC
    // ---------------------
    if (_chromaticXOff != 0.0 || _chromaticYOff != 0.0) {
        vec4 r = sampleTex(targetVec + vec2(_chromaticXOff, _chromaticYOff));
        vec4 b = sampleTex(targetVec + vec2(-_chromaticXOff, -_chromaticYOff));
        gl_FragColor = vec4(r.r, gl_FragColor.g, b.b, max(r.a, max(gl_FragColor.a,b.a)));
    }

    // ---------------------
    // RADIALBLUR
    // ---------------------
    if (_radialBlurValue != 0.0) {
        vec4 result = gl_FragColor;
        if (!_blurOnlyEmpty || result.a < 0.1) {
            vec2 uv = targetVec;
            vec2 blurVector = (applyRotation(_radialBlurCenter) - uv) * _radialBlurValue;
            float modVal = 1.0 + 4.5*_blurFade;
            result *= modVal;
            for (int i = 1; i < radialBlurSamples; i++) {
                modVal -= _blurFade;
                uv.xy += blurVector.xy;
                result += sampleTex(uv) * modVal;
            }

            result *= radialBlurSamplesInv;

            // Output to screen
            if (_blurUseRef) {
                gl_FragColor = vec4((result.rgb + _blurRefColor * (1.0-result.a)), result.a * _blurIntensity);
            }
            else gl_FragColor = result;
        }
    }
    // ---------------------
    // MOTIONBLUR
    // ---------------------
    else if (_motionBlurValue.x != 0.0 || _motionBlurValue.y != 0.0)
    {
        //vec4 result = sampleTex(targetVec);
        vec4 result = gl_FragColor;

        if (!_blurOnlyEmpty || result.a < 0.1) {
            if (_motionBlurDual) {
                for (float i = 1.0; i < mbSamplesLoopDual; ++i) {
                    float modVal = 1.0 - (i * _blurFade);
                    vec2 offset = _motionBlurValue * (i * mbSamplesDualInv);
                    result += sampleTex(targetVec + offset) * modVal;
                    result += sampleTex(targetVec - offset) * modVal;
                }
            }
            else {
                for (float i = 1.0; i < mbSamplesLoop; ++i) {
                    float modVal = 1.0 - (i * _blurFade);
                    vec2 offset = _motionBlurValue * (i * mbSamplesInv);
                    result += sampleTex(targetVec + offset) * modVal;
                }
            }

            result *= _motionBlurMult; // 1/(9 - 20 * _blurFade)

            if (_blurUseRef) {
                gl_FragColor = vec4((result.rgb + _blurRefColor * (1.0-result.a)), result.a * _blurIntensity);
            }
            else gl_FragColor = result;
        }
    }

    // ---------------------
    // GRAYSCALE
    // ---------------------
    if (_grayscaleValue > 0.0) {
        float gray = !_grayscaleUseLum ? (gl_FragColor.r + gl_FragColor.g + gl_FragColor.b)*0.333 : dot(gl_FragColor.rgb, vec3(0.299, 0.587, 0.114));

        gl_FragColor.rgb = gl_FragColor.rgb*(1.0-_grayscaleValue) + vec3(gray)*_grayscaleValue*_grayscaleTint;
    }

    // ---------------------
    // SEPIA
    // ---------------------
    if (_sepiaValue > 0.0) {
        vec4 texColor = gl_FragColor * sepiaMat;
        gl_FragColor.rgb = gl_FragColor.rgb*(1.0-_sepiaValue) + texColor.rgb*_sepiaValue;
    }

    // ---------------------
    // INVERTCOLOR
    // ---------------------
    if (_invertColorValue.a > 0.0) {
        vec4 texColor = 1.0 - gl_FragColor;
        gl_FragColor.rgb = gl_FragColor.rgb * (1.0 - _invertColorValue.rgb) + texColor.rgb * _invertColorValue.rgb;
    }

    // ---------------------
    // HUESHIFT
    // ---------------------
    if (_hueShiftCosA != 0.0) {
        gl_FragColor.rgb = vec3(gl_FragColor.rgb * _hueShiftCosA + cross(_hueShiftK, gl_FragColor.rgb) * _hueShiftSinA + _hueShiftK * dot(_hueShiftK, gl_FragColor.rgb) * (1.0 - _hueShiftCosA));
    }

    // ---------------------
    // COLORCHANGE
    // ---------------------
    if (_colorChangeC.r > 0.0) {
        gl_FragColor.rgb = gl_FragColor.rgb * _colorChangeC + _colorChangeB;
    }

    // ---------------------
    // LENSCIRCLE
    // ---------------------
    if (_lensCircleStrength > 0.0) {
        float dist = distance(scaledTexCoord * _textureScaleInv, applyRotation(_lensCircleOrigin));
        float k = _lensCircleStart == _lensCircleEnd ? ((dist >= _lensCircleEnd ? _lensCircleStrength : 0.0)) : _lensCircleStrength * (1.0 - smoothstep(_lensCircleEnd, _lensCircleStart, dist));
        if (_lensCircleAdditive) gl_FragColor.rgb = gl_FragColor.rgb + (_lensCircleTint * k);
        else gl_FragColor.rgb = gl_FragColor.rgb * (1.0 - k) + (_lensCircleTint * k);
    }
}
