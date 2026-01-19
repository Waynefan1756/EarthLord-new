// supabase/functions/generate-ai-item/index.ts
// AI 物品生成 Edge Function
// 调用阿里云百炼 qwen-turbo 模型生成末日风格物品

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// CORS 响应头
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

// 阿里云百炼国际版 API（Supabase 在海外需要使用国际版）
const DASHSCOPE_API_KEY = Deno.env.get("DASHSCOPE_API_KEY");
const DASHSCOPE_API_URL = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions";

// 请求接口
interface POIContext {
  name: string;
  type: string;
  dangerLevel: number;
}

interface GenerateRequest {
  poi: POIContext;
  itemCount: number;
}

// 响应接口
interface GeneratedItem {
  id: string;
  name: string;
  category: string;
  rarity: string;
  story: string;
  quantity: number;
}

interface GenerateResponse {
  items: GeneratedItem[];
  generatedAt: string;
  model: string;
}

// 根据危险等级确定稀有度分布提示
function getRarityDistribution(dangerLevel: number): string {
  switch (dangerLevel) {
    case 1:
      return "90%普通(common)、10%优良(uncommon)";
    case 2:
      return "70%普通(common)、20%优良(uncommon)、10%稀有(rare)";
    case 3:
      return "50%普通(common)、30%优良(uncommon)、15%稀有(rare)、5%史诗(epic)";
    case 4:
      return "30%普通(common)、30%优良(uncommon)、25%稀有(rare)、12%史诗(epic)、3%传说(legendary)";
    case 5:
      return "10%普通(common)、20%优良(uncommon)、35%稀有(rare)、25%史诗(epic)、10%传说(legendary)";
    default:
      return "70%普通(common)、20%优良(uncommon)、10%稀有(rare)";
  }
}

// POI 类型中文映射
function getPOITypeName(type: string): string {
  const typeMap: Record<string, string> = {
    supermarket: "超市",
    hospital: "医院",
    pharmacy: "药店",
    gasStation: "加油站",
    gas_station: "加油站",
    factory: "工厂",
    warehouse: "仓库",
    residential: "住宅区",
    convenience_store: "便利店",
    restaurant: "餐厅",
  };
  return typeMap[type] || type;
}

// 构建系统提示词
const SYSTEM_PROMPT = `你是一个末日生存游戏的物品生成器。游戏背景是丧尸末日后的世界。

生成规则：
1. 物品名称要有创意（15字以内），可以暗示前主人身份或物品来历
2. 背景故事要简短有画面感（30-60字），营造末日氛围
3. 物品类别要与地点相关（医院出医疗物品，超市出食物）
4. 稀有度越高，名称越独特，故事越精彩
5. 可以有黑色幽默，但不要太血腥

物品分类说明：
- food: 食物（罐头、饼干、能量棒等）
- water: 水类（矿泉水、纯净水、饮料等）
- medical: 医疗用品（绷带、药品、急救包等）
- material: 材料（木材、金属、布料、电池等）
- tool: 工具（手电筒、绳子、工具箱、收音机等）
- weapon: 武器（棍棒、刀具、防身器具等）
- misc: 杂项（衣物、日用品等）

稀有度说明：
- common: 普通（灰色）- 常见物品
- uncommon: 优良（绿色）- 较好的物品
- rare: 稀有（蓝色）- 不常见的好物品
- epic: 史诗（紫色）- 非常稀有的好物品
- legendary: 传说（橙色）- 极其稀有的珍贵物品

只返回 JSON 数组，不要其他任何内容（不要 markdown 代码块）。`;

// 构建用户提示词
function buildUserPrompt(poi: POIContext, itemCount: number): string {
  const rarityDistribution = getRarityDistribution(poi.dangerLevel);
  const poiTypeName = getPOITypeName(poi.type);

  return `搜刮地点：${poi.name}（${poiTypeName}类型，危险等级 ${poi.dangerLevel}/5）

请生成 ${itemCount} 个物品。

稀有度分布参考：${rarityDistribution}

返回格式示例：
[{"name":"物品名称","category":"food","rarity":"common","story":"物品故事","quantity":1}]

请生成 ${itemCount} 个物品的 JSON 数组。`;
}

// 调用阿里云百炼 API
async function callDashScope(poi: POIContext, itemCount: number): Promise<GeneratedItem[]> {
  const response = await fetch(DASHSCOPE_API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${DASHSCOPE_API_KEY}`,
    },
    body: JSON.stringify({
      model: "qwen-turbo",
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: buildUserPrompt(poi, itemCount) }
      ],
      temperature: 0.8,
      max_tokens: 1500,
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    console.error("[generate-ai-item] DashScope API error:", response.status, errorText);
    throw new Error(`DashScope API error: ${response.status}`);
  }

  const data = await response.json();
  const content = data.choices?.[0]?.message?.content;

  if (!content) {
    throw new Error("Empty response from DashScope");
  }

  // 解析 JSON（处理可能的 markdown 代码块）
  let jsonStr = content.trim();
  if (jsonStr.startsWith("```")) {
    jsonStr = jsonStr.replace(/```json?\n?/g, "").replace(/```/g, "").trim();
  }

  const items = JSON.parse(jsonStr);

  // 验证并补充字段
  return items.map((item: Record<string, unknown>) => ({
    id: crypto.randomUUID(),
    name: String(item.name || "未知物品"),
    category: String(item.category || "misc"),
    rarity: String(item.rarity || "common"),
    story: String(item.story || ""),
    quantity: Number(item.quantity) || 1,
  }));
}

// 主处理函数
Deno.serve(async (req: Request) => {
  // 处理 CORS 预检请求
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // 验证 API Key 配置
    if (!DASHSCOPE_API_KEY) {
      console.error("[generate-ai-item] DASHSCOPE_API_KEY not configured");
      throw new Error("AI service not configured");
    }

    // 解析请求体
    const body: GenerateRequest = await req.json();
    const { poi, itemCount = 3 } = body;

    // 验证 POI 参数
    if (!poi || !poi.name || !poi.type || typeof poi.dangerLevel !== "number") {
      throw new Error("Invalid POI context: name, type, and dangerLevel are required");
    }

    // 验证物品数量
    const validItemCount = Math.min(Math.max(itemCount, 1), 5);

    console.log(`[generate-ai-item] Generating ${validItemCount} items for ${poi.name} (danger: ${poi.dangerLevel})`);

    // 调用 AI 生成
    const items = await callDashScope(poi, validItemCount);

    // 构建响应
    const response: GenerateResponse = {
      items,
      generatedAt: new Date().toISOString(),
      model: "qwen-turbo",
    };

    console.log(`[generate-ai-item] Generated ${items.length} items successfully`);

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    console.error("[generate-ai-item] Error:", error);

    const errorMessage = error instanceof Error ? error.message : "Unknown error";

    return new Response(
      JSON.stringify({
        error: errorMessage,
        items: [],
        generatedAt: new Date().toISOString(),
        model: "qwen-turbo",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
