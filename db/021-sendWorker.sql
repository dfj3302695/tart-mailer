Create unique index EmailSendQueueI on EmailSend (sendOrder) where state = 'new';

Create or replace function CancelNotAllowedEmailSend(fromAddress varchar(200) default null)
    returns setof EmailSend
    language sql
    as $$
Update EmailSend
    set state = 'cancel'
    where state = 'new'
            and ((fromAddress, toAddress) in (select fromAddress, toAddress
                        from Subscriber
                            where state in ('cancel', 'responseReport', 'unsubscribe'))
                    or (fromAddress, emailId) in (select fromAddress, emailId
                                from Email
                                    where state = 'cancel')
                    or (fromAddress, emailId) in (select fromAddress, emailId
                                from EmailVariation
                                    group by fromAddress, emailId
                                        having min(state) = 'cancel'))
    returning *
$$;

Create or replace function EmailToSendCount(fromAddress varchar(200) default null)
    returns bigint
    language sql
    as $$
Select count(*)
    from EmailSend
        join Email using (fromAddress, emailId)
        where EmailSend.state = 'new'
                and (EmailToSendCount.fromAddress is null
                        or EmailSend.fromAddress = EmailToSendCount.fromAddress)
                and Email.state = 'sent'
                and (EmailSend.fromAddress, EmailSend.emailId) in (select fromAddress, emailId
                            from EmailVariation
                                where state = 'sent')
$$;

Create or replace function NextEmailToSend(
        messageFrame int default 1,
        fromAddress varchar(200) default null
    ) returns table (
        fromName varchar(200),
        fromAddress varchar(200),
        toAddress varchar(200),
        subject varchar(1000),
        plainBody text,
        hTMLBody text,
        unsubscribeURL text,
        bulk boolean
    )
    language sql
    as $$
With FirstWaitingEmail as (select EmailSend.fromAddress,
                EmailSend.toAddress,
                EmailSend.emailId,
                EmailVariation.variationId,
                EmailVariation.subject,
                EmailVariation.plainBody,
                EmailVariation.hTMLBody,
                Email.bulk
            from EmailSend
                join EmailVariation using (fromAddress, emailId)
                join Email using (fromAddress, emailId)
                where EmailSend.state = 'new'
                        and Email.state = 'sent'
                        and EmailVariation.state = 'sent'
                        and (NextEmailToSend.fromAddress is null
                                or EmailSend.fromAddress = NextEmailToSend.fromAddress)
                order by EmailSend.sendOrder
                    limit 1
                    offset random() * NextEmailToSend.messageFrame),
    EmailToSend as (update EmailSend
            set state = 'sent',
                    variationId = FirstWaitingEmail.variationId
            from FirstWaitingEmail
                where EmailSend.fromAddress = FirstWaitingEmail.fromAddress
                        and EmailSend.toAddress = FirstWaitingEmail.toAddress
                        and EmailSend.emailId = FirstWaitingEmail.emailId
            returning FirstWaitingEmail.*,
                    EmailSend)
    select Sender.fromName,
            Sender.fromAddress,
            Subscriber.toAddress,
            FormatEmailToSend(EmailToSend.subject, Subscriber.properties),
            FormatEmailToSend(EmailToSend.plainBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(EmailToSend.EmailSend)),
            FormatEmailToSend(EmailToSend.hTMLBody, Subscriber.properties, Sender.returnURLRoot,
                              MessageHash(EmailToSend.EmailSend)),
            Sender.returnURLRoot || 'unsubscribe/' || MessageHash(EmailToSend.EmailSend),
            EmailToSend.bulk
        from EmailToSend
            join Sender using (fromAddress)
            join Subscriber using (fromAddress, toAddress)
$$;
