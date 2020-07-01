//=============================================================================
// Performs a separable Guassian blur with a blur radius up to 5 pixels.
//=============================================================================

// Update to Shader Model 5.1

// Now use bilateral blur

/*
cbuffer cbSettings : register(b0)
{
	// We cannot have an array entry in a constant buffer that gets mapped onto
	// root constants, so list each element.  
	
	int gBlurRadius;

	// Support up to 11 blur weights.
	float w0;
	float w1;
	float w2;
	float w3;
	float w4;
	float w5;
	float w6;
	float w7;
	float w8;
	float w9;
	float w10;
};
*/

struct SettingConstants {
	// We cannot have an array entry in a constant buffer that gets mapped onto
	// root constants, so list each element.  

	int gBlurRadius;

	// Support up to 11 blur weights.
	float w0;
	float w1;
	float w2;
	float w3;
	float w4;
	float w5;
	float w6;
	float w7;
	float w8;
	float w9;
	float w10;
};

ConstantBuffer<SettingConstants> gSettingConstants : register(b0);

static const int gMaxBlurRadius = 5;

Texture2D gInput            : register(t0);
RWTexture2D<float4> gOutput : register(u0);

#define N 256
#define CacheSize (N + 2*gMaxBlurRadius)
groupshared float4 gCache[CacheSize];

static const float SigmaColor = 0.05f;
static const float TwoSigmaColor2 = 2.0f * SigmaColor * SigmaColor;
float colorIntensityDifference(float3 color1, float3 color2) {
	float3 colorDifference = color1 - color2;
	return dot(colorDifference, colorDifference) / TwoSigmaColor2;
}

[numthreads(N, 1, 1)]
void HorzBlurCS(int3 groupThreadID : SV_GroupThreadID,
				int3 dispatchThreadID : SV_DispatchThreadID)
{
	// Put in an array for each indexing.
	float weights[11] = { 
		gSettingConstants.w0,
		gSettingConstants.w1,
		gSettingConstants.w2,
		gSettingConstants.w3,
		gSettingConstants.w4,
		gSettingConstants.w5,
		gSettingConstants.w6,
		gSettingConstants.w7,
		gSettingConstants.w8,
		gSettingConstants.w9,
		gSettingConstants.w10
	};

	//
	// Fill local thread storage to reduce bandwidth.  To blur 
	// N pixels, we will need to load N + 2*BlurRadius pixels
	// due to the blur radius.
	//
	
	// This thread group runs N threads.  To get the extra 2*BlurRadius pixels, 
	// have 2*BlurRadius threads sample an extra pixel.
	if(groupThreadID.x < gSettingConstants.gBlurRadius)
	{
		// Clamp out of bound samples that occur at image borders.
		int x = max(dispatchThreadID.x - gSettingConstants.gBlurRadius, 0);
		gCache[groupThreadID.x] = gInput[int2(x, dispatchThreadID.y)];
	}
	if(groupThreadID.x >= N - gSettingConstants.gBlurRadius)
	{
		// Clamp out of bound samples that occur at image borders.
		int x = min(dispatchThreadID.x + gSettingConstants.gBlurRadius, gInput.Length.x-1);
		gCache[groupThreadID.x + 2 * gSettingConstants.gBlurRadius] = gInput[int2(x, dispatchThreadID.y)];
	}

	// Clamp out of bound samples that occur at image borders.
	gCache[groupThreadID.x + gSettingConstants.gBlurRadius] = gInput[min(dispatchThreadID.xy, gInput.Length.xy-1)];

	// Wait for all threads to finish.
	GroupMemoryBarrierWithGroupSync();
	
	//
	// Now blur each pixel.
	//

	// Modify: consider color intensity difference besides spacial difference

	int centerIdx = groupThreadID.x + gSettingConstants.gBlurRadius;
	float4 centerPixelColor = gCache[centerIdx];
	float totalWeight = 0.0f;

	float4 blurColor = float4(0, 0, 0, 0);
	
	for(int i = -gSettingConstants.gBlurRadius; i <= gSettingConstants.gBlurRadius; ++i)
	{
		int k = centerIdx + i;
		
		float4 currentPixelColor = gCache[k];
		float spacialWeight = weights[i + gSettingConstants.gBlurRadius];
		float intensityWeight = exp(-colorIntensityDifference(currentPixelColor.rgb, centerPixelColor.rgb));
		float finalWeigth =  intensityWeight;

		blurColor += finalWeigth * currentPixelColor;
		totalWeight += finalWeigth;
	}
	
	gOutput[dispatchThreadID.xy] = blurColor / totalWeight;
}

[numthreads(1, N, 1)]
void VertBlurCS(int3 groupThreadID : SV_GroupThreadID,
				int3 dispatchThreadID : SV_DispatchThreadID)
{
	// Put in an array for each indexing.
	float weights[11] = {
		gSettingConstants.w0,
		gSettingConstants.w1,
		gSettingConstants.w2,
		gSettingConstants.w3,
		gSettingConstants.w4,
		gSettingConstants.w5,
		gSettingConstants.w6,
		gSettingConstants.w7,
		gSettingConstants.w8,
		gSettingConstants.w9,
		gSettingConstants.w10
	};

	//
	// Fill local thread storage to reduce bandwidth.  To blur 
	// N pixels, we will need to load N + 2*BlurRadius pixels
	// due to the blur radius.
	//
	
	// This thread group runs N threads.  To get the extra 2*BlurRadius pixels, 
	// have 2*BlurRadius threads sample an extra pixel.
	if(groupThreadID.y < gSettingConstants.gBlurRadius)
	{
		// Clamp out of bound samples that occur at image borders.
		int y = max(dispatchThreadID.y - gSettingConstants.gBlurRadius, 0);
		gCache[groupThreadID.y] = gInput[int2(dispatchThreadID.x, y)];
	}
	if(groupThreadID.y >= N- gSettingConstants.gBlurRadius)
	{
		// Clamp out of bound samples that occur at image borders.
		int y = min(dispatchThreadID.y + gSettingConstants.gBlurRadius, gInput.Length.y-1);
		gCache[groupThreadID.y+2* gSettingConstants.gBlurRadius] = gInput[int2(dispatchThreadID.x, y)];
	}
	
	// Clamp out of bound samples that occur at image borders.
	gCache[groupThreadID.y+ gSettingConstants.gBlurRadius] = gInput[min(dispatchThreadID.xy, gInput.Length.xy-1)];


	// Wait for all threads to finish.
	GroupMemoryBarrierWithGroupSync();
	
	//
	// Now blur each pixel.
	//

	// Modify: consider color intensity difference besides spacial difference

	int centerIdx = groupThreadID.y + gSettingConstants.gBlurRadius;
	float4 centerPixelColor = gCache[centerIdx];
	float totalWeight = 0.0f;

	float4 blurColor = float4(0, 0, 0, 0);

	for (int i = -gSettingConstants.gBlurRadius; i <= gSettingConstants.gBlurRadius; ++i) {
		int k = centerIdx + i;

		float4 currentPixelColor = gCache[k];
		float spacialWeight = weights[i + gSettingConstants.gBlurRadius];
		float intensityWeight = exp(-colorIntensityDifference(currentPixelColor.rgb, centerPixelColor.rgb));
		float finalWeigth =  intensityWeight;

		blurColor += finalWeigth * currentPixelColor;
		totalWeight += finalWeigth;
	}

	gOutput[dispatchThreadID.xy] = blurColor / totalWeight;
}