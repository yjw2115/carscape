# 얼어붙은 밤 스테이지 에셋

## 장면 이미지

OpenAI 이미지 생성 도구로 제작한 신규 장면입니다. 첨부 예시는 도면과 측정기의 시각적 참고 자료로 사용했습니다. 실제 회로 경로와 측정 수치는 게임에서 그립니다.

### `blueprint.jpg`

Use case: illustration-story. Game asset for premium automotive escape room. Create a precision orthographic automotive technical blueprint of a fictional modern compact crossover, TOP VIEW only, front pointing up. Portrait canvas 2:3. Perfect bilateral symmetry, vehicle centered, taking 92% of the height and about 67% width. Detailed fine midnight navy and desaturated blue ink on uniform warm ivory #e9e0cd paper. X-ray cutaway show the positions of the front left and front right seats at about 42% down and rear left and rear right seats about 62% down, four defined contoured seats, front windscreen, steering wheel on left, cabin panels and cargo floor at rear (bottom), wheels, lamps, mirrors, seam lines and mechanical hatch detail. Professional industrial design drawing, fine crisp linework, varied stroke weights, technical construction lines and dimension ticks without digits. No labels, text, title, logos, arrows, added diagram wires or circuit overlays. No other viewpoints. No cast shadow. No detached components. We will draw interactive wiring overlay later.

### `cabin.jpg`

Use case: stylized-concept. Premium cinematic photoreal game environment plate, 16:9 wide. View from inside a modern unbranded car at night in a winter mountain snowstorm, centered on passenger side air vents near midframe, viewed from driver seat. Dashboard low in frame and foreground on the right, substantial passenger window and windshield with delicate thick ice crystals along edge and cold cyan moonlight. A tactile horizontal metallic air vent and dashboard surfaces with fine dew, physical soft light. Composition has understated, desaturated charcoal and midnight blue. A restrained soft warm amber light under the air vent that will serve as warm-up glow, primarily icy scene. No people, no UI, no captions, no glowing text, no exterior building, no labels or logos. Clean composed realistic survival game art, low enough contrast on far left to accommodate a UI overlay.

### `road.jpg`

Use case: stylized-concept. Photoreal high-end survival videogame environment plate, wide 16:9. View forward from the windshield of a parked car during a winter evening. Quiet mountain forest road in a blizzard. Road begins near bottom center and makes a visually legible clear right-hand bend to a believable roadside emergency shelter on the RIGHT at x75% y52%, about 25% of frame width. Shelter is a detailed sturdy timber mountain refuge with snow-laden roof, one warmly glowing amber entrance and window, realistic wood siding, discreet external lantern, no writing. Detailed snowy fir trees, snow banks, subtle wind-driven snow, layered blue-gray dusk and natural soft headlight illumination on the snow track. Keep shelter and right curve recognizable in a center crop at a 4:3 ratio. Mood severe cold and distant warmth, cinematic realistic materials. Only outside view, no dashboard, no wiper, no frost, no glass overlays, no text, no watermark. We composite windshield frost and wiper in-game.

### `frost.jpg`

Use case: photorealistic-natural. Wide 16:9 windshield frost texture for a winter videogame, an almost opaque frosted-up flat glass surface filling the entire picture edge to edge. Macro photographic fine fern-shaped ice dendrites, clear clustered crystals, opaque snow and densely textured bluish white freezing fog. Subtle dark steel-blue patches in the middle and thick packed granular snow along bottom, irregular icy crust and small ice granules on glass. Entire camera field is the frosted glass, no visible scenery, no people, no frame or windows divisions, no logo, no text, no black framing. Natural icy translucency and realistic microdetail, cold desaturated teal blue and gray-white colors. No discrete snowflake icons and no illustration.

### `windshield_snow.jpg`

OpenAI 이미지 생성 도구로 제작했습니다. 첨부 사진은 앞유리 위 눈 입자의 질감을 참고하는 데 사용했습니다.

Create a new wide 16:9 production game texture for Carscape, photographed from inside a car through its windshield, almost entirely blocked by fresh accumulated SNOW on the exterior glass. Use the supplied final reference photo in the request only as visual inspiration for the granular powder (do not recreate its exterior angle, black car frame or wipers). Fill the canvas completely with snowy buildup: matte white and pale neutral blue-gray loose fine snow grains, fluffy clumpy small wind-packed drifts softly banked along the bottom, subtly uneven density with mottled dark graphite-blue patches in the upper/middle field that remain opaque with snow particles. Photorealistic tactile snow, cool evening light, distinguish clearly from the crystal frost in preceding scene. Absolutely no fern-shaped ice crystals, crystal branches, frost flowers, frozen sheets, icicles, icelike blue shards, glass cracks, wiper tracks, wipers, borders, cabin, scenery, outlines, text or logos. No holes or transparent regions. Top to bottom snow covering the full width. We composite over the existing road and wipe this full-bleed texture in code.

### `cabin_gas.png`

OpenAI 이미지 생성 도구로 제작한 반투명 연기입니다. 첨부 사진의 회색 연기 밀도와 흐름을 참고했습니다.

Generate a wide 16:9 production texture for a dark cinematic escape room game. Isolated photorealistic billowing wisps of pale warm-gray smoke, with a slightly tawny tint and deep soft folds, suspended on a genuinely fully transparent alpha background. The smoke forms several soft irregular cloudy billows across the canvas with pronounced wisps and varying density, asymmetrically concentrated around the left and bottom edges but some streams drifting across center. Atmosphere of smoke filling a dark car cabin, completely obscured underlying scene is NOT part of the image: only semitransparent volumetric aerosol. Low-saturation beige gray, no green, no flame, no sparks, no text, no logos, no objects, no black colored background. Naturally tapered feathered edges and many transparent openings in between. Artwork will be composited behind game gauges, create fine granular detail and volumetric shadows while maintaining opacity falloff.

## 한국어 대사

Pleos에서 나레이션 음량이 100%인 경우 TextToSpeech SDK의 한국어 온디바이스 합성을 우선 사용합니다. 기기가 TTS를 지원하지 않거나 앱에서 음성 음량을 줄인 경우 아래의 내장 음원으로 재생합니다. [Pleos TextToSpeech SDK](https://document.pleos.ai/api-reference/connect-sdk-pleos/TextToSpeech/intro)

`voice/`의 WAV 9개는 [Supertonic 3](https://huggingface.co/Supertone/supertonic-3)으로 로컬에서 합성했습니다. 운전석은 M1, 조수석은 F3, 나레이터는 M4 음색입니다. 구절마다 말의 속도, 음높이, 세기와 쉼을 조절했습니다. 정전 장면의 다급한 질문, 가스 발견 순간의 놀람, 도착 후의 안도가 서로 다르게 들리도록 편집했습니다. 원본 대사는 `lib/features/tutorial/domain/tutorial_script.dart`에 있습니다. [모델 이용 조건](https://huggingface.co/Supertone/supertonic-3/blob/main/LICENSE)

## 배경음악과 클리어 효과음

`assets/audio/`의 배경음악은 제공받은 `carscape-home-loop.wav`와 `carscape-frozen-night-loop.wav`입니다. 곡의 시작과 끝을 짧게 페이드하고 끝에 5초 무음을 추가했습니다. 클리어 효과음은 제공받은 `carscape-chapter-clear-mystery-resolve-temp.wav`를 사용합니다.
