// Include common HLSL code.
#include "Common.hlsl"

struct VertexIn {
	float3 PosL    : POSITION;
	float3 NormalL : NORMAL;
	float2 TexC    : TEXCOORD;
};

struct VertexOut {
	float3 PosL    : POSITION;
	float3 NormalW : NORMAL;
	float2 TexC    : TEXCOORD;
};

struct GeometryOut {
	float4 PosH    : SV_POSITION;
	float3 PosW    : POSITION;
	float3 NormalW : NORMAL;
	float2 TexC    : TEXCOORD;

	uint RTIndex : SV_RenderTargetArrayIndex;
};

VertexOut VS(VertexIn vin) {
	VertexOut vout = (VertexOut)0.0f;

	vout.PosL = vin.PosL;

	// Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
	vout.NormalW = mul(vin.NormalL, (float3x3)gObjectConstants.gWorld);

	// Fetch the material data.
	MaterialData matData = gMaterialData[gObjectConstants.gMaterialIndex];

	// Output vertex attributes for interpolation across triangle.
	float4 texC = mul(float4(vin.TexC, 0.0f, 1.0f), gObjectConstants.gTexTransform);
	vout.TexC = mul(texC, matData.MatTransform).xy;

	return vout;
}

[maxvertexcount(18)]
void GS(triangle VertexOut gin[3], inout TriangleStream<GeometryOut> triangleStream) {
	for (int faceIdx = 0; faceIdx < 6; ++faceIdx) {
		GeometryOut gout;

		gout.RTIndex = faceIdx;
		// offset 1 because the first one is not for cube mapping (player camera)
		int faceConstantsIdx = faceIdx + 1;

		for (int vertexIdx = 0; vertexIdx < 3; ++vertexIdx) {
			// Transform to world space.
			float4 posW = mul(float4(gin[vertexIdx].PosL, 1.0f), gObjectConstants.gWorld);

			gout.PosW = posW.xyz;
			// choose corresponding camera setting to do transforming
			gout.PosH = mul(posW, gPassConstants.gViewProj[faceConstantsIdx]);
			gout.TexC = gin[vertexIdx].TexC;
			gout.NormalW = gin[vertexIdx].NormalW;

			triangleStream.Append(gout);
		}
		triangleStream.RestartStrip();
	}
}

float4 PS(GeometryOut pin) : SV_Target
{
	// Fetch the material data.
	MaterialData matData = gMaterialData[gObjectConstants.gMaterialIndex];
	float4 diffuseAlbedo = matData.DiffuseAlbedo;
	float3 fresnelR0 = matData.FresnelR0;
	float  roughness = matData.Roughness;
	uint diffuseTexIndex = matData.DiffuseMapIndex;

	// Dynamically look up the texture in the array.
	diffuseAlbedo *= gDiffuseMap[diffuseTexIndex].Sample(gsamAnisotropicWrap, pin.TexC);

	// Interpolating normal can unnormalize it, so renormalize it.
	pin.NormalW = normalize(pin.NormalW);

	// Vector from point being lit to eye. 
	float3 toEyeW = normalize(gPassConstants.gEyePosW[pin.RTIndex + 1].xyz - pin.PosW);

	// Light terms.
	float4 ambient = gPassConstants.gAmbientLight * diffuseAlbedo;

	const float shininess = 1.0f - roughness;
	Material mat = { diffuseAlbedo, fresnelR0, shininess };
	float3 shadowFactor = 1.0f;
	float4 directLight = ComputeLighting(gPassConstants.gLights, mat, pin.PosW,
		pin.NormalW, toEyeW, shadowFactor);

	float4 litColor = ambient + directLight;

	// Add in specular reflections.
	float3 r = reflect(-toEyeW, pin.NormalW);
	float4 reflectionColor = gCubeMap.Sample(gsamLinearWrap, r);
	float3 fresnelFactor = SchlickFresnel(fresnelR0, pin.NormalW, r);
	litColor.rgb += shininess * fresnelFactor * reflectionColor.rgb;

	// Common convention to take alpha from diffuse albedo.
	litColor.a = diffuseAlbedo.a;

	return litColor;
}

float4 PS_Dielectric(GeometryOut pin) : SV_Target
{
	// Fetch the material data.
	MaterialData matData = gMaterialData[gObjectConstants.gMaterialIndex];
	float4 diffuseAlbedo = matData.DiffuseAlbedo;
	float3 fresnelR0 = matData.FresnelR0;
	float  roughness = matData.Roughness;
	uint diffuseTexIndex = matData.DiffuseMapIndex;

	// Dynamically look up the texture in the array.
	diffuseAlbedo *= gDiffuseMap[diffuseTexIndex].Sample(gsamAnisotropicWrap, pin.TexC);

	// Interpolating normal can unnormalize it, so renormalize it.
	pin.NormalW = normalize(pin.NormalW);

	// Vector from point being lit to eye. 
	float3 toEyeW = normalize(gPassConstants.gEyePosW[pin.RTIndex + 1].xyz - pin.PosW);

	// Light terms.
	float4 ambient = gPassConstants.gAmbientLight * diffuseAlbedo;

	const float shininess = 1.0f - roughness;
	Material mat = { diffuseAlbedo, fresnelR0, shininess };
	float3 shadowFactor = 1.0f;
	float4 directLight = ComputeLighting(gPassConstants.gLights, mat, pin.PosW,
		pin.NormalW, toEyeW, shadowFactor);

	float4 litColor = ambient + directLight;

	// Add refractions.
	float3 r = refract(-toEyeW, pin.NormalW, 1.0f / 1.5f);
	float4 refractionColor = gCubeMap.Sample(gsamLinearWrap, r);
	float3 fresnelFactor = SchlickFresnel(fresnelR0, pin.NormalW, r);
	litColor.rgb += shininess * fresnelFactor * refractionColor.rgb;

	// Common convention to take alpha from diffuse albedo.
	litColor.a = diffuseAlbedo.a;

	return litColor;
}