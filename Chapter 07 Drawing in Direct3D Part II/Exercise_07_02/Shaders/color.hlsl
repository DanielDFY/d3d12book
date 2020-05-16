//***************************************************************************************
// color.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Transforms and colors geometry.
//***************************************************************************************
 
// Update to Shader Model 5.1

/*
cbuffer cbPerObject : register(b0)
{
	float4x4 gWorld; 
};
*/

// Modify: Now use root constants instead of a descriptor table
//         to set the per-object world matrix

/*
struct ObjectConstants {
    float4x4 gWorld;
};
*/

struct ObjectConstants
{
	float gWorld00;
	float gWorld01;
	float gWorld02;
	float gWorld03;
	float gWorld10;
	float gWorld11;
	float gWorld12;
	float gWorld13;
	float gWorld20;
	float gWorld21;
	float gWorld22;
	float gWorld23;
	float gWorld30;
	float gWorld31;
	float gWorld32;
	float gWorld33;
};

ConstantBuffer<ObjectConstants> gObjectConstants : register(b0);

/*
cbuffer cbPass : register(b1)
{
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
};
*/

struct PassConstants {
    float4x4 gView;
    float4x4 gInvView;
    float4x4 gProj;
    float4x4 gInvProj;
    float4x4 gViewProj;
    float4x4 gInvViewProj;
    float3 gEyePosW;
    float cbPerObjectPad1;
    float2 gRenderTargetSize;
    float2 gInvRenderTargetSize;
    float gNearZ;
    float gFarZ;
    float gTotalTime;
    float gDeltaTime;
};

ConstantBuffer<PassConstants> gPassConstants : register(b1);

struct VertexIn
{
	float3 PosL  : POSITION;
    float4 Color : COLOR;
};

struct VertexOut
{
	float4 PosH  : SV_POSITION;
    float4 Color : COLOR;
};

VertexOut VS(VertexIn vin)
{
	VertexOut vout;

    float4x4 world = float4x4(
		float4(gObjectConstants.gWorld00, gObjectConstants.gWorld01, gObjectConstants.gWorld02, gObjectConstants.gWorld03),
		float4(gObjectConstants.gWorld10, gObjectConstants.gWorld11, gObjectConstants.gWorld12, gObjectConstants.gWorld13),
		float4(gObjectConstants.gWorld20, gObjectConstants.gWorld21, gObjectConstants.gWorld22, gObjectConstants.gWorld23),
		float4(gObjectConstants.gWorld30, gObjectConstants.gWorld31, gObjectConstants.gWorld32, gObjectConstants.gWorld33));
	
	// Transform to homogeneous clip space.
    /*
    float4 posW = mul(float4(vin.PosL, 1.0f), gWorld);
    vout.PosH = mul(posW, gViewProj);
    */
    /*
    float4 posW = mul(float4(vin.PosL, 1.0f), gObjectConstants.gWorld);
	*/
    float4 posW = mul(float4(vin.PosL, 1.0), world);
    vout.PosH = mul(posW, gPassConstants.gViewProj);

	// Just pass vertex color into the pixel shader.
    vout.Color = vin.Color;
    
    return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
    return pin.Color;
}


