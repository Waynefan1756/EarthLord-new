-- Day 34: 发送频道消息 RPC 函数
CREATE OR REPLACE FUNCTION send_channel_message(
    p_channel_id UUID,
    p_content TEXT,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_device_type TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_message_id UUID;
    v_sender_id UUID;
    v_callsign TEXT;
    v_location GEOGRAPHY(POINT, 4326);
    v_metadata JSONB;
BEGIN
    v_sender_id := auth.uid();

    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE channel_id = p_channel_id AND user_id = v_sender_id
    ) THEN
        RAISE EXCEPTION '您未订阅此频道，无法发送消息';
    END IF;

    -- 查询 username（profiles 表使用 username 字段）
    SELECT COALESCE(username, '匿名幸存者')
    INTO v_callsign
    FROM public.profiles
    WHERE id = v_sender_id;

    IF v_callsign IS NULL THEN
        v_callsign := '匿名幸存者';
    END IF;

    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;
    END IF;

    v_metadata := jsonb_build_object('device_type', COALESCE(p_device_type, 'unknown'));

    INSERT INTO public.channel_messages (
        channel_id, sender_id, sender_callsign, content, sender_location, metadata
    )
    VALUES (
        p_channel_id, v_sender_id, v_callsign, p_content, v_location, v_metadata
    )
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
