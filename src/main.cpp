#include <Geode/Geode.hpp>

using namespace geode::prelude;

#include <numbers>

#include <Geode/modify/ShaderLayer.hpp>
class $modify(ShaderLayer) {
    struct Fields {
        GLint m_camRotUniform;
    };

    void visit() {
        auto* director = CCDirector::get();
        float saved = director->m_fContentScaleFactor;
        director->m_fContentScaleFactor = m_renderTexture->getSprite()->getTexture()->getContentSizeInPixels().height / director->getWinSize().height;
        ShaderLayer::visit();
        director->m_fContentScaleFactor = saved;
    }

    CCPoint prepareTargetContainer() {
        // pixelate fix
        auto targetSize = m_renderTexture->getSprite()->getTexture()->getContentSizeInPixels();
        float savedX = m_state.m_pixelateTargetX;
        float savedY = m_state.m_pixelateTargetY;
        m_state.m_pixelateTargetX = targetSize.width / std::round(m_textureContentSize.width / m_state.m_pixelateTargetX);
        m_state.m_pixelateTargetY = targetSize.height / std::round(m_textureContentSize.height / m_state.m_pixelateTargetY);
        // can't change content scale factor here because it's used later in the same function
        m_state.m_pixelateTargetX /= CCDirector::get()->getContentScaleFactor();
        m_state.m_pixelateTargetY /= CCDirector::get()->getContentScaleFactor();

        // camera rotation fix
        CCNode* robTopsEpicNode = m_state.m_blurRefChannel < 2 ?
            m_gameLayer->m_unknownE90 : m_gameLayer->m_unknownE98;
        float rot = robTopsEpicNode->getRotation();
        robTopsEpicNode->setRotation(0.f);

        auto res = ShaderLayer::prepareTargetContainer();

        robTopsEpicNode->setRotation(rot);
        m_shader->setUniformLocationWith2f(m_fields->m_camRotUniform,
            std::cos(rot * (std::numbers::pi_v<float> / 180.f)),
            std::sin(rot * (std::numbers::pi_v<float> / 180.f))
        );

        m_state.m_pixelateTargetX = savedX;
        m_state.m_pixelateTargetY = savedY;

        return res;
    }

    // pixelate fix
    void prePixelateShader() {
        if (m_state.m_pixelateTargetX > 1.f || m_state.m_pixelateTargetY > 1.f ||
            this->getActionByTag(9) || this->getActionByTag(10)) {
            m_state.m_usesShaders = true;
            m_state.m_pixelatePixelating = true;
        }
        else {
            m_state.m_pixelatePixelating = false;
        }
        if (m_state.m_pixelateTargetX <= 1.f && m_state.m_pixelateTargetY <= 1.f) {
            this->toggleAntiAlias(m_configuredAntiAlias);
            m_state.m_textureScaleX = 1.f;
            m_state.m_textureScaleY = 1.f;
            m_renderTexture->updateInternalScale(0.f, 0.f);
            m_sprite->setScaleX(1.f);
            m_sprite->setScaleY(1.f);
            return;
        }
        this->toggleAntiAlias(!m_state.m_pixelateHardEdges);
        auto targetSize = m_renderTexture->getSprite()->getTexture()->getContentSizeInPixels();
        float zoom = m_state.m_pixelateRelative && m_gameLayer ?
            std::abs(m_gameLayer->m_objectLayer->getScale()) : 1.f;
        if (m_state.m_pixelateTargetX < 1.f)
            m_state.m_pixelateTargetX = 1.f;
        if (m_state.m_pixelateTargetY < 1.f)
            m_state.m_pixelateTargetY = 1.f;
        float scaledTargetX = zoom * targetSize.width / std::round(m_textureContentSize.width / m_state.m_pixelateTargetX);
        float scaledTargetY = zoom * targetSize.height / std::round(m_textureContentSize.height / m_state.m_pixelateTargetY);
        if (scaledTargetX < 1.f)
            scaledTargetX = 1.f;
        if (scaledTargetY < 1.f)
            scaledTargetY = 1.f;
        float scaledTargetXInv = 1.f / scaledTargetX;
        float scaledTargetYInv = 1.f / scaledTargetY;
        m_state.m_textureScaleX = scaledTargetXInv;
        m_state.m_textureScaleY = scaledTargetYInv;
        m_renderTexture->updateInternalScale(scaledTargetXInv, scaledTargetYInv);
        m_sprite->setScaleX(scaledTargetX);
        m_sprite->setScaleY(scaledTargetY);
    }

    void setupShader(bool shouldReset) {
        if (m_sprite) {
            m_sprite->removeFromParent();
            m_sprite = nullptr;
        }
        if (m_renderTexture) {
            m_renderTexture->release();
            m_renderTexture = nullptr;
        }
        auto* shaderCache = CCShaderCache::sharedShaderCache();
        m_shader = shaderCache->programForKey("custom_program");
        if (!m_shader) {
            m_shader = new CCGLProgram();
            shaderCache->addProgram(m_shader, "custom_program");
            m_shader->release();
            shouldReset = true;
        }
        else if (shouldReset) {
            m_shader->reset();
        }
        if (shouldReset) {
            std::filesystem::path vertexPath =
                (std::string)CCFileUtils::get()->fullPathForFilename("pp-vert.glsl"_spr, false);
            auto vertexSource = file::readString(vertexPath);
            if (!vertexSource) {
                log::error("failed to read vertex shader at path {}: {}", vertexPath.string(),
                    vertexSource.unwrapErr());
            }

            std::filesystem::path fragmentPath =
                (std::string)CCFileUtils::get()->fullPathForFilename("pp-frag.glsl"_spr, false);
            auto fragmentSource = file::readString(fragmentPath);
            if (!fragmentSource) {
                log::error("failed to read fragment shader at path {}: {}", fragmentPath.string(),
                    fragmentSource.unwrapErr());
            }

            if (!vertexSource || !fragmentSource) {
                log::error("some shader failed to load... game will crash !!!!!!!");
            }

            m_shader->initWithVertexShaderByteArray(vertexSource.unwrap().c_str(), fragmentSource.unwrap().c_str());
            m_shader->addAttribute("a_position", 0);
            m_shader->addAttribute("a_color", 1);
            m_shader->addAttribute("a_texCoord", 2);
            m_shader->link();
            m_shader->updateUniforms();
            GameManager::get()->m_shouldResetShader = false;
        }

        auto* director = CCDirector::get();

        auto visibleSize = director->getVisibleSize();
        auto targetSize = director->getOpenGLView()->getFrameSize() * utils::getDisplayFactor();

        float savedContentScaleFactor = director->m_fContentScaleFactor;
        director->m_fContentScaleFactor = 1.f;
        m_renderTexture = CCRenderTexture::create((int)targetSize.width, (int)targetSize.height, kCCTexture2DPixelFormat_RGBA8888);
        director->m_fContentScaleFactor = savedContentScaleFactor;

        m_renderTexture->retain();

        float cringe = std::sqrt(visibleSize.width * visibleSize.width + visibleSize.height * visibleSize.height);
        float scaleFactorX = director->getScreenScaleFactorW();
        m_shockWaveTimeMult = visibleSize.width / cringe;
        m_shockWaveTimeMult /= 480.f / std::sqrt(480.f * 480.f + 320.f * 320.f);
        m_shockWaveTimeMult /= scaleFactorX;

        m_textureContentSize = CCSize(std::floor(cringe), std::floor(cringe));
        m_targetTextureSize = visibleSize;
        m_targetTextureSizeExtra = m_targetTextureSize - visibleSize;

        m_sprite = CCSprite::create();
        m_sprite->setTexture(m_renderTexture->getSprite()->getTexture());
        m_sprite->setTextureRect(CCRect(-1.f, -1.f, m_targetTextureSize.width + 2.f, m_targetTextureSize.height + 2.f));
        m_sprite->setPosition(ccp(0.f, 0.f));
        m_sprite->setAnchorPoint(ccp(0.f, 0.f));
        m_sprite->setFlipY(true);
        this->addChild(m_sprite);
        m_sprite->setShaderProgram(m_shader);

        m_configuredAntiAlias = !GameManager::get()->getGameVariable("0155");
        this->toggleAntiAlias(m_configuredAntiAlias);

        GLint robHackUniform = m_shader->getUniformLocationForName("_robHack");
        m_shader->setUniformLocationWith2f(robHackUniform, visibleSize.width / std::floor(cringe), visibleSize.height / std::floor(cringe));
        m_fields->m_camRotUniform = m_shader->getUniformLocationForName("_camRot");

        // setupCommonUniforms
        m_textureScaleUniform = m_shader->getUniformLocationForName("_textureScale");
        m_textureScaleInvUniform = m_shader->getUniformLocationForName("_textureScaleInv");
        m_shaderPositionUniform = m_shader->getUniformLocationForName("_shaderPosition");
        m_blurRefColorUniform = m_shader->getUniformLocationForName("_blurRefColor");
        m_blurUseRefUniform = m_shader->getUniformLocationForName("_blurUseRef");
        m_blurIntensityUniform = m_shader->getUniformLocationForName("_blurIntensity");
        m_blurFadeUniform = m_shader->getUniformLocationForName("_blurFade");
        m_blurOnlyEmptyUniform = m_shader->getUniformLocationForName("_blurOnlyEmpty");

        // setupShockWaveUniforms
        m_shockWaveTimeUniform = m_shader->getUniformLocationForName("_shockWaveTime");
        m_shockWaveTime1Uniform = m_shader->getUniformLocationForName("_shockWaveTime1");
        m_shockWaveTime2Uniform = m_shader->getUniformLocationForName("_shockWaveTime2");
        m_shockWaveTime3Uniform = m_shader->getUniformLocationForName("_shockWaveTime3");
        m_shockWaveTime4Uniform = m_shader->getUniformLocationForName("_shockWaveTime4");
        m_shockWaveStrengthUniform = m_shader->getUniformLocationForName("_shockWaveStrength");
        m_shockWaveWavesUniform = m_shader->getUniformLocationForName("_shockWaveWaves");
        m_shockWaveCenterUniform = m_shader->getUniformLocationForName("_shockWaveCenter");
        m_shockWaveInvertUniform = m_shader->getUniformLocationForName("_shockWaveInvert");
        m_shockWaveMinSizeUniform = m_shader->getUniformLocationForName("_shockWaveMinSize");
        m_shockWaveMaxSizeUniform = m_shader->getUniformLocationForName("_shockWaveMaxSize");
        m_shockWaveMaxDistValUniform = m_shader->getUniformLocationForName("_shockWaveMaxDistVal");

        // setupShockLineUniforms
        m_shockLineTimeUniform = m_shader->getUniformLocationForName("_shockLineTime");
        m_shockLineTime1Uniform = m_shader->getUniformLocationForName("_shockLineTime1");
        m_shockLineTime2Uniform = m_shader->getUniformLocationForName("_shockLineTime2");
        m_shockLineTime3Uniform = m_shader->getUniformLocationForName("_shockLineTime3");
        m_shockLineTime4Uniform = m_shader->getUniformLocationForName("_shockLineTime4");
        m_shockLineAxisUniform = m_shader->getUniformLocationForName("_shockLineAxis");
        m_shockLineDirectionUniform = m_shader->getUniformLocationForName("_shockLineDirection");
        m_shockLineDualUniform = m_shader->getUniformLocationForName("_shockLineDual");
        m_shockLineWavesUniform = m_shader->getUniformLocationForName("_shockLineWaves");
        m_shockLineStrengthUniform = m_shader->getUniformLocationForName("_shockLineStrength");
        m_shockLineCenterUniform = m_shader->getUniformLocationForName("_shockLineCenter");
        m_shockLineMaxDistValUniform = m_shader->getUniformLocationForName("_shockLineMaxDistVal");

        // setupGlitchUniforms
        m_glitchBotUniform = m_shader->getUniformLocationForName("_glitchBot");
        m_glitchTopUniform = m_shader->getUniformLocationForName("_glitchTop");
        m_glitchXOffsetUniform = m_shader->getUniformLocationForName("_glitchXOffset");
        m_glitchColOffsetUniform = m_shader->getUniformLocationForName("_glitchColOffset");
        m_glitchRndUniform = m_shader->getUniformLocationForName("_glitchRnd");

        // setupChromaticUniforms
        m_chromaticXOffUniform = m_shader->getUniformLocationForName("_chromaticXOff");
        m_chromaticYOffUniform = m_shader->getUniformLocationForName("_chromaticYOff");

        // setupChromaticGlitchUniforms
        m_cGRGBOffsetUniform = m_shader->getUniformLocationForName("_cGRGBOffset");
        m_cGYOffsetUniform = m_shader->getUniformLocationForName("_cGYOffset");
        m_cGTimeUniform = m_shader->getUniformLocationForName("_cGTime");
        m_cGStrengthUniform = m_shader->getUniformLocationForName("_cGStrength");
        m_cGHeightUniform = m_shader->getUniformLocationForName("_cGHeight");
        m_cGLineThickUniform = m_shader->getUniformLocationForName("_cGLineThick");
        m_cGLineStrengthUniform = m_shader->getUniformLocationForName("_cGLineStrength");

        // setupLensCircleShader
        m_lensCircleOriginUniform = m_shader->getUniformLocationForName("_lensCircleOrigin");
        m_lensCircleStartUniform = m_shader->getUniformLocationForName("_lensCircleStart");
        m_lensCircleEndUniform = m_shader->getUniformLocationForName("_lensCircleEnd");
        m_lensCircleStrengthUniform = m_shader->getUniformLocationForName("_lensCircleStrength");
        m_lensCircleTintUniform = m_shader->getUniformLocationForName("_lensCircleTint");
        m_lensCircleAdditiveUniform = m_shader->getUniformLocationForName("_lensCircleAdditive");

        // setupRadialBlurShader
        m_radialBlurCenterUniform = m_shader->getUniformLocationForName("_radialBlurCenter");
        m_radialBlurValueUniform = m_shader->getUniformLocationForName("_radialBlurValue");

        // setupBulgeShader
        m_bulgeValueUniform = m_shader->getUniformLocationForName("_bulgeValue");
        m_bulgeValue2Uniform = m_shader->getUniformLocationForName("_bulgeValue2");
        m_bulgeOriginUniform = m_shader->getUniformLocationForName("_bulgeOrigin");
        m_bulgeRadiusUniform = m_shader->getUniformLocationForName("_bulgeRadius");

        // setupBulgeShader
        m_pinchValueUniform = m_shader->getUniformLocationForName("_pinchValue");
        m_pinchCenterPosUniform = m_shader->getUniformLocationForName("_pinchCenterPos");
        m_pinchCalcUniform = m_shader->getUniformLocationForName("_pinchCalc1");
        m_pinchRadiusUniform = m_shader->getUniformLocationForName("_pinchRadius");

        // setupMotionBlurShader
        m_motionBlurValueUniform = m_shader->getUniformLocationForName("_motionBlurValue");
        m_motionBlurMultUniform = m_shader->getUniformLocationForName("_motionBlurMult");
        m_motionBlurDualUniform = m_shader->getUniformLocationForName("_motionBlurDual");

        // setupGrayscaleShader
        m_grayscaleValueUniform = m_shader->getUniformLocationForName("_grayscaleValue");
        m_grayscaleTintUniform = m_shader->getUniformLocationForName("_grayscaleTint");
        m_grayscaleUseLumUniform = m_shader->getUniformLocationForName("_grayscaleUseLum");

        // setupSepiaShader
        m_sepiaValueUniform = m_shader->getUniformLocationForName("_sepiaValue");

        // setupInvertColorShader
        m_invertColorValueUniform = m_shader->getUniformLocationForName("_invertColorValue");

        // setupHueShiftShader
        m_hueShiftCosAUniform = m_shader->getUniformLocationForName("_hueShiftCosA");
        m_hueShiftSinAUniform = m_shader->getUniformLocationForName("_hueShiftSinA");

        // setupColorChangeShader
        m_colorChangeCUniform = m_shader->getUniformLocationForName("_colorChangeC");
        m_colorChangeBUniform = m_shader->getUniformLocationForName("_colorChangeB");

        // setupSplitScreenShader
        m_rowmodUniform = m_shader->getUniformLocationForName("_rowmod");
        m_colmodUniform = m_shader->getUniformLocationForName("_colmod");
        m_rowmodCalcUniform = m_shader->getUniformLocationForName("_rowmodCalc");
        m_colmodCalcUniform = m_shader->getUniformLocationForName("_colmodCalc");
        m_splitXStartUniform = m_shader->getUniformLocationForName("_splitXStart");
        m_splitXRangeUniform = m_shader->getUniformLocationForName("_splitXRange");
        m_splitXRangeMultUniform = m_shader->getUniformLocationForName("_splitXRangeMult");
        m_splitYStartUniform = m_shader->getUniformLocationForName("_splitYStart");
        m_splitYRangeUniform = m_shader->getUniformLocationForName("_splitYRange");
        m_splitYRangeMultUniform = m_shader->getUniformLocationForName("_splitYRangeMult");
    }
};
