-- Day 34: 频道消息表
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS public.channel_messages (
    message_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.communication_channels(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    sender_callsign TEXT,
    content TEXT NOT NULL,
    sender_location GEOGRAPHY(POINT, 4326),
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.channel_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "订阅者可以查看频道消息" ON public.channel_messages
    FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.channel_subscriptions
            WHERE channel_subscriptions.channel_id = channel_messages.channel_id
            AND channel_subscriptions.user_id = auth.uid()
        )
    );

CREATE POLICY "订阅者可以发送消息" ON public.channel_messages
    FOR INSERT TO authenticated
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.channel_subscriptions
            WHERE channel_subscriptions.channel_id = channel_messages.channel_id
            AND channel_subscriptions.user_id = auth.uid()
        )
    );

CREATE INDEX idx_messages_channel ON public.channel_messages(channel_id);
CREATE INDEX idx_messages_sender ON public.channel_messages(sender_id);
CREATE INDEX idx_messages_created ON public.channel_messages(created_at DESC);

-- 启用 Realtime 推送
ALTER PUBLICATION supabase_realtime ADD TABLE channel_messages;
