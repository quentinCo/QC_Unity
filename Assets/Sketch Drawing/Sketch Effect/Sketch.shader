Shader "Hidden/Sketch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [IntRange] _Range("Range", Range(1, 32)) = 16
        [IntRange] _AngleVariation("Orientation Variation", Range(2,8)) = 4
        _Threshold("Threshold", Range(0.001, 1)) = 0.1
        _BackgroundMix("Background Mix", Range(0, 1)) = 0.1
        _Reduction("Reduction", Range(1,100)) = 10
        _Details("Details", Range(0.1, 1)) = 0.5
        _Color("Color", Color) = (0,0,0,1)
    }
    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            #define PI 3.14159265358

            #define STEP 2

            #define MAX_RANGE 128
            #define MAX_ORIENTATION 16

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }


            // Fragment shader
            // -- Uniforms
            sampler2D   _MainTex;
            float4      _MainTex_TexelSize;

            int         _Range;
            int         _AngleVariation;
            float       _Threshold;
            float       _BackgroundMix;
            float       _Reduction;
            float       _Details;
            float4      _Color;

            // -- Functions
            float getValue(float x, float y)
            {
                const float3 luminance = float3(0.299, 0.587, 0.114);
                float4 color = tex2D(_MainTex, float2(x, y));
                return dot(color.xyz, luminance);
            }

            float2 getGrad(float2 pos, float delta)
            {
                float deltaX = delta * _MainTex_TexelSize.x;
                float deltaY = delta * _MainTex_TexelSize.y;
                
                float x = getValue(pos.x - deltaX, pos.y) - getValue(pos.x + deltaX, pos.y);
                float y = getValue(pos.x, pos.y - deltaY) - getValue(pos.x, pos.y + deltaY);

                float2 grad = float2(x, y);
                float details = max(0.1, 1 - _Details);
                return grad / (delta * details);
            }

            void decreaseWeight(float k, float2 fragCoord, float2 dir, float2 ortho, float factor, inout float weight )
            {
                float2 pos = fragCoord + dir * k * _MainTex_TexelSize.xy;
                if (pos.x < 0 || pos.y < 0 || pos.x > _MainTex_TexelSize.z || pos.y > _MainTex_TexelSize.w)
                    return;

                float2 grad = getGrad(pos, 1.);
                if (length(grad) < _Threshold)
                    return;

                weight -= pow(abs(dot(normalize(grad), ortho)), _Reduction) * factor;
            }


            // -- Main
            fixed4 frag (v2f i) : SV_Target
            {
                float minOrientation = min(_AngleVariation,MAX_ORIENTATION);

                float angleStep = PI / minOrientation;
                
                float2 fragCoord = i.uv;
                float weight = 1.0;

                for (int j = 0; j < MAX_ORIENTATION; ++j)
                {
                    if (j >= minOrientation)
                        break;

                    float angle     = j * angleStep;
                    float2 dir      = float2(cos(angle), sin(angle));
                    float2 ortho    = float2(-dir.y, dir.x);

                    float minRange  = min(_Range, MAX_RANGE);
                    float factor    = 1 / (floor((2 * minRange + 1.0) / STEP) * minOrientation);
                    for (int k = 0; k <= MAX_RANGE; k += STEP)
                    {
                        if (k > minRange)
                            break;

                        decreaseWeight(k, fragCoord, dir, ortho, factor, weight);

                        if (k > 0)
                            decreaseWeight(-k, fragCoord, dir, ortho, factor, weight);
                    }
                }

                fixed4 color = tex2D(_MainTex, i.uv);
                fixed4 background = lerp(color, float4(1, 1, 1, 1), (1 - _BackgroundMix));

                fixed4 fragColor = lerp(_Color, background, weight);
                
                return fragColor;
            }
            ENDCG
        }
    }
}
