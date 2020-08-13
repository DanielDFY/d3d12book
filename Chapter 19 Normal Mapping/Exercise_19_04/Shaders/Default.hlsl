//***************************************************************************************
// Default.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//***************************************************************************************

// Exercise_19_04 Default.hlsl modified by DanielDFY

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
	float3 TangentT : TANGENT;
};

struct VertexOut
{
	float4 PosH    : SV_POSITION;
	float3 PosW    : POSITION;
	float3 NormalW : NORMAL;
	float3 TangentW  : TANGENT;
	float3 BinormalW : BINORMAL;
	float2 TexC    : TEXCOORD;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout = (VertexOut)0.0f;

	// Fetch the material data.
	MaterialData matData = gMaterialData[gObjectConstants.gMaterialIndex];
	
    // Transform to world space.
    float4 posW = mul(float4(vin.PosL, 1.0f), gObjectConstants.gWorld);
    vout.PosW = posW.xyz;

	// Transform to homogeneous clip space.
	vout.PosH = mul(posW, gPassConstants.gViewProj);

    // Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
    vout.NormalW = mul(vin.NormalL, (float3x3)gObjectConstants.gWorld);
	
	// Transfrom texture u-axis from texture space to world space
	vout.TangentW = mul(vin.TangentT, (float3x3)gObjectConstants.gWorld);

	// Get texture v-axis in world space
	vout.BinormalW = cross(vout.TangentW, vout.NormalW);
	
	// Output vertex attributes for interpolation across triangle.
	float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gObjectConstants.gTexTransform);
	vout.TexC = mul(texC, matData.MatTransform).xy;
	
    return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
	// Fetch the material data.
	MaterialData matData = gMaterialData[gObjectConstants.gMaterialIndex];
	float4 diffuseAlbedo = matData.DiffuseAlbedo;
	float3 fresnelR0 = matData.FresnelR0;
	float  roughness = matData.Roughness;
	uint diffuseMapIndex = matData.DiffuseMapIndex;
	uint normalMapIndex = matData.NormalMapIndex;
	
	// Renormalize after interpolation.
	float3 T = normalize(pin.TangentW);
	float3 B = normalize(pin.BinormalW);
	float3 N = normalize(pin.NormalW);

	// Build space transformation matrices with TBN.
	float3x3 textureToWorld = float3x3(T, B, N);
	float3x3 worldToTexture = transpose(textureToWorld);

	// Sample the normal map.
	float4 normalMapSample = gTextureMaps[normalMapIndex].Sample(gsamAnisotropicWrap, pin.TexC);
	float3 bumpedNormalT = 2.0f * normalMapSample.rgb - 1.0f;
	
	// Vector from point being lit to eye. 
	float3 toEyeW = normalize(gPassConstants.gEyePosW - pin.PosW);

	// Transform to texture space to do lighting
	float3 posT = mul(pin.PosW, worldToTexture);
	float3 toEyeT = mul(toEyeW, worldToTexture);

	Light lights[MaxLights];
	int lightCount = NUM_DIR_LIGHTS + NUM_POINT_LIGHTS + NUM_SPOT_LIGHTS;
	for (int i = 0; i < lightCount; ++i) {
		lights[i].Strength = gPassConstants.gLights[i].Strength;
		lights[i].Direction = mul(gPassConstants.gLights[i].Direction, worldToTexture);
		lights[i].Position = mul(gPassConstants.gLights[i].Position, worldToTexture);
	}

	// Dynamically look up the texture in the array.
	diffuseAlbedo *= gTextureMaps[diffuseMapIndex].Sample(gsamAnisotropicWrap, pin.TexC);

    // Light terms.
    float4 ambient = gPassConstants.gAmbientLight*diffuseAlbedo;

    const float shininess = (1.0f - roughness) * normalMapSample.a;
    Material mat = { diffuseAlbedo, fresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(lights, mat, posT, bumpedNormalT, toEyeT, shadowFactor);

    float4 litColor = ambient + directLight;

	// Add in specular reflections.
	float3 bumpedNormalW = mul(bumpedNormalT, textureToWorld);
	float3 r = reflect(-toEyeW, bumpedNormalW);
	float4 reflectionColor = gCubeMap.Sample(gsamLinearWrap, r);
	float3 fresnelFactor = SchlickFresnel(fresnelR0, bumpedNormalW, r);
    litColor.rgb += shininess * fresnelFactor * reflectionColor.rgb;
	
    // Common convention to take alpha from diffuse albedo.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}


