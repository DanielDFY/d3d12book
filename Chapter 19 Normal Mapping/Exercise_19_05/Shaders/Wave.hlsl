//***************************************************************************************
// Wave.hlsl by DanielDFT for Exceise_19_05
//***************************************************************************************

// Defaults for number of lights.
#ifndef NUM_DIR_LIGHTS
    #define NUM_DIR_LIGHTS 3
#endif

#ifndef NUM_POINT_LIGHTS
    #define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
    #define NUM_SPOT_LIGHTS 0
#endif

// Include common HLSL code.
#include "Common.hlsl"

struct VertexIn
{
	float3 PosL    : POSITION;
    float3 NormalL : NORMAL;
	float2 TexC    : TEXCOORD;
	float3 TangentU : TANGENT;
};

struct VertexOut
{
	float4 PosH    : SV_POSITION;
    float3 PosW    : POSITION;
    float3 NormalW : NORMAL;
	float3 TangentW : TANGENT;
	float2 TexC    : TEXCOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout = (VertexOut)0.0f;

	// Fetch the material data.
	MaterialData matData = gMaterialData[gObjectConstants.gMaterialIndex];

	// Output vertex attributes for interpolation across triangle.
	float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gObjectConstants.gTexTransform);
	vout.TexC = mul(texC, matData.MatTransform).xy;

	// Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
	vout.NormalW = mul(vin.NormalL, (float3x3)gObjectConstants.gWorld);
	vout.TangentW = mul(vin.TangentU, (float3x3)gObjectConstants.gWorld);

	// Model high frequency choppy waves with low amplitude
	uint choppyWaveHeightMapIndex = matData.NormalMapIndex + 1;
	float2 choppyWaveTexC = vout.TexC + gPassConstants.gTotalTime * 0.1f;	// different tex coords
	float choppyWaveHeight = gTextureMaps[choppyWaveHeightMapIndex].SampleLevel(gsamAnisotropicWrap, choppyWaveTexC, 0).r;

	// Model low frequency broad waves with high amplitude
	uint broadWaveHeightMapIndex = matData.NormalMapIndex + 3;
	float2 broadWaveTexC = vout.TexC - gPassConstants.gTotalTime * 0.1f;	// different tex coords
	float broadWaveHeight = gTextureMaps[broadWaveHeightMapIndex].SampleLevel(gsamAnisotropicWrap, broadWaveTexC, 0).r;

	// Transform to world space.
	float4 posW = mul(float4(vin.PosL, 1.0f), gObjectConstants.gWorld);
	posW += float4((choppyWaveHeight + broadWaveHeight) * vout.NormalW, 0.0f);	// displace input position
	vout.PosW = posW.xyz;
	
	// Transform to homogeneous clip space.
	vout.PosH = mul(posW, gPassConstants.gViewProj);

	return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
	// Fetch the material data.
	MaterialData matData = gMaterialData[gObjectConstants.gMaterialIndex];
	float4 diffuseAlbedo = matData.DiffuseAlbedo;
	float3 fresnelR0 = matData.FresnelR0;
	float roughness = matData.Roughness;
	uint diffuseMapIndex = matData.DiffuseMapIndex;

	// Interpolating normal can unnormalize it, so renormalize it.
	pin.NormalW = normalize(pin.NormalW);

	// Model high frequency choppy waves with low amplitude
	uint choppyWaveNormalMapIndex = matData.NormalMapIndex;
	float2 choppyWaveTexC = pin.TexC + gPassConstants.gTotalTime * 0.1f;	// different tex coords
	float4 choppyWaveNormalMapSample = gTextureMaps[choppyWaveNormalMapIndex].Sample(gsamAnisotropicWrap, choppyWaveTexC);
	float3 choppyWaveBumpedNormalW = NormalSampleToWorldSpace(choppyWaveNormalMapSample.rgb, pin.NormalW, pin.TangentW);

	// Model low frequency broad waves with high amplitude
	uint broadWaveNormalMapIndex = matData.NormalMapIndex + 2;
	float2 broadWaveTexC = pin.TexC - gPassConstants.gTotalTime * 0.1f;	// different tex coords
	float4 broadWaveNormalMapSample = gTextureMaps[broadWaveNormalMapIndex].Sample(gsamAnisotropicWrap, broadWaveTexC);
	float3 broadWaveBumpedNormalW = NormalSampleToWorldSpace(broadWaveNormalMapSample.rgb, pin.NormalW, pin.TangentW);

	// bump input normal
	float3 bumpedNormalW = normalize(choppyWaveBumpedNormalW + broadWaveBumpedNormalW);

	// Dynamically look up the texture in the array.
	diffuseAlbedo *= gTextureMaps[diffuseMapIndex].Sample(gsamAnisotropicWrap, pin.TexC);

    // Vector from point being lit to eye. 
    float3 toEyeW = normalize(gPassConstants.gEyePosW - pin.PosW);

    // Light terms.
    float4 ambient = gPassConstants.gAmbientLight * diffuseAlbedo;

    const float shininess = (1.0f - roughness) * choppyWaveNormalMapSample.a;
    Material mat = { diffuseAlbedo, fresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gPassConstants.gLights, mat, pin.PosW,
        bumpedNormalW, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

	// Add in specular reflections.
	float3 r = reflect(-toEyeW, bumpedNormalW);
	float4 reflectionColor = gCubeMap.Sample(gsamAnisotropicWrap, r);
	float3 fresnelFactor = SchlickFresnel(fresnelR0, bumpedNormalW, r);
    litColor.rgb += shininess * fresnelFactor * reflectionColor.rgb;
	
    // Common convention to take alpha from diffuse albedo.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}


