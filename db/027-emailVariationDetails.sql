Create or replace view EmailVariationDetail as
    select EmailSend.emailId, EmailSend.variationRank as rank,
            count(*) as total,
            count(EmailSendResponseReport) as responseReport,
            sum((EmailSendFeedback.type = 'trackerImage')::int) as trackerImage,
            sum((EmailSendFeedback.type = 'view')::int) as view,
            sum((EmailSendFeedback.type = 'redirect')::int) as redirect,
            sum((EmailSendFeedback.type = 'unsubscribe')::int) as unsubscribe
        from EmailSend
            left join EmailSendResponseReport on EmailSendResponseReport.emailId = EmailSend.emailId
                    and EmailSend.subscriberId = EmailSendResponseReport.subscriberId
            left join EmailSendFeedback on EmailSendFeedback.emailId = EmailSend.emailId
                    and EmailSend.subscriberId = EmailSendFeedback.subscriberId
            where EmailSend.sent
            group by EmailSend.emailId, EmailSend.variationRank
            order by EmailSend.emailId, EmailSend.variationRank;