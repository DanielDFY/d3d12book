//***************************************************************************************
// Default.hlsl by Frank Luna (C) 2015 All Rights Reserved.
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
	MaterialData matData = gMaterialData[gMaterialIndex];
	uint diffuseMapIndex = matData.DiffuseMapIndex;
	// Output vertex attributes for interpolation across triangle.
	float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gTexTransform);
	//vout.TexC = mul(texC, matData.MatTransform).xy;
	vout.TexC = vin.TexC;
	
	float height0 = 0.7f * gTextureMaps[2].SampleLevel(gsamPointWrap, vout.TexC, 0).r;    //–°≤®¿À 
	float2 texC1 =  float2(0.08f * vin.TexC.x * (1.0f + gTotalTime),0.15f* vin.TexC.y * (1.0f + gTotalTime) );
	float height1 = 0.5f * gTextureMaps[4].SampleLevel(gsamPointWrap, texC1, 0).r;           //¥Û≤®¿À
	// Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
	vout.NormalW = mul(vin.NormalL, (float3x3)gWorld);
    // Transform to world space.
    float4 posW = mul(float4(vin.PosL, 1.0f), gWorld);
	posW += float4((height0+height1) * vout.NormalW,0.0f);
    vout.PosW = posW.xyz;

    
	
	vout.TangentW = mul(vin.TangentU, (float3x3)gWorld);

    // Transform to homogeneous clip space.
    vout.PosH = mul(posW, gViewProj);
	
	
	
    return vout;
}

float4 PS(VertexOut pin) : SV_Target
{

	// Fetch the material data.
	MaterialData matData = gMaterialData[gMaterialIndex];
	float4 diffuseAlbedo = matData.DiffuseAlbedo;
	float3 fresnelR0 = matData.FresnelR0;
	float  roughness = matData.Roughness;
	uint diffuseMapIndex = matData.DiffuseMapIndex;
	uint normalMapIndex = matData.NormalMapIndex;
	
	// Interpolating normal can unnormalize it, so renormalize it.
    pin.NormalW = normalize(pin.NormalW);

	//float height = gTextureMaps[0].SampleLevel(gsamAnisotropicWrap, pin.TexC,0).r;
	//pin.PosW += float4(height * pin.NormalW, 0.0f);
	//pin.PosH = pin.PosW.xyz;
	//pin.PosH = mul(pin.PosW, gViewProj);

	//float4 normalMapSample = gTextureMaps[normalMapIndex].Sample(gsamAnisotropicWrap, pin.TexC);
	//float3 bumpedNormalW = NormalSampleToWorldSpace(normalMapSample.rgb, pin.NormalW, pin.TangentW);
	float2 texC0 = mul(float4(pin.TexC, 0.0f, 1.0f), gTexTransform).xy;
	float2 texC1 = float2(0.08f * pin.TexC.x * (1.0f + gTotalTime), 0.15f* pin.TexC.y * (1.0f + gTotalTime));
	float4 normalMapSample0 = gTextureMaps[3].Sample(gsamLinearWrap, texC0);
	float3 bumpedNormalW0 = NormalSampleToWorldSpace(normalMapSample0.rgb, pin.NormalW, pin.TangentW);
	float4 normalMapSample1 = gTextureMaps[5].Sample(gsamLinearWrap, texC1);
	float3 bumpedNormalW1 = NormalSampleToWorldSpace(normalMapSample1.rgb, pin.NormalW, pin.TangentW);
	float3 bumpedNormalW = normalize(bumpedNormalW0+bumpedNormalW1);
	// Uncomment to turn off normal mapping.
	//bumpedNormalW = pin.NormalW;

	// Dynamically look up the texture in the array.
	//diffuseAlbedo *= gTextureMaps[diffuseMapIndex].Sample(gsamAnisotropicWrap, pin.TexC);

    // Vector from point being lit to eye. 
    float3 toEyeW = normalize(gEyePosW - pin.PosW);

    // Light terms.
    float4 ambient = gAmbientLight*diffuseAlbedo;

    const float shininess = (1.0f - roughness) * normalMapSample0.a;
    Material mat = { diffuseAlbedo, fresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gLights, mat, pin.PosW,
        bumpedNormalW, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

	// Add in specular reflections.
	float3 r = reflect(-toEyeW, bumpedNormalW);
	float4 reflectionColor = gCubeMap.Sample(gsamLinearWrap, r);
	float3 fresnelFactor = SchlickFresnel(fresnelR0, bumpedNormalW, r);
    litColor.rgb += shininess * fresnelFactor * reflectionColor.rgb;
	
    // Common convention to take alpha from diffuse albedo.
    litColor.a = diffuseAlbedo.a;

    return litColor;
}


