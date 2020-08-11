// Include common HLSL code.
#include "Common.hlsl"

struct VertexIn {
	float3 PosL    : POSITION;
	float3 NormalL : NORMAL;
	float2 TexC    : TEXCOORD;
};

struct VertexOut {
	float3 PosL    : POSITION;
};

struct GeometryOut {
	float4 PosH    : SV_POSITION;
	float3 PosL    : POSITION;

	uint RTIndex : SV_RenderTargetArrayIndex;
};

VertexOut VS(VertexIn vin) {
	VertexOut vout = (VertexOut)0.0f;

	vout.PosL = vin.PosL;

	return vout;
}

[maxvertexcount(18)]
void GS(triangle VertexOut gin[3], inout TriangleStream<GeometryOut> triangleStream) {
	for (int faceIdx = 0; faceIdx < 6; ++faceIdx) {
		GeometryOut gout;

		gout.RTIndex = faceIdx;
		
		for (int vertexIdx = 0; vertexIdx < 3; ++vertexIdx) {
			gout.PosL = gin[vertexIdx].PosL;
			float4 posW = mul(float4(gin[vertexIdx].PosL, 1.0f), gObjectConstants.gWorld);
			gout.PosH = mul(posW, gPassConstants.gViewProj[faceIdx + 1]);

			triangleStream.Append(gout);
		}
		triangleStream.RestartStrip();
	}
}

float4 PS(GeometryOut pin) : SV_Target
{
	return gCubeMap.Sample(gsamLinearWrap, pin.PosL);
}