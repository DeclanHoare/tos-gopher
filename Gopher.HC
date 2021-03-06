/* Gopher client for TempleOS/Sockets
   by Declan Hoare 2020
   Public Domain - No Warranty */

#define GOPHER_CLIENT_LOADED

#ifndef GOPHER_ASSOCIATIONS
#define GOPHER_ASSOCIATIONS
U8* gopher_associations[256];
#endif

I64 GopherOpen(U8* host, U16 port, U8* selector, U8* query)
{
	U8* line;
	I64 sock;
	
	if (host == NULL)
	{
		return -1;
	}
	
	sock = create_connection(host, port);
	if (sock < 0)
	{
		PrintErr("Failed to connect to %s:%d\n", host, port);
		return sock;
	}
	
	if (query == NULL)
	{
		line = StrPrint(NULL, "%s\r\n", selector);
	}
	else
	{
		line = StrPrint(NULL, "%s\t%s\r\n", selector, query);
	}
	
	sendString(sock, line, 0);
	Free(line);
	
	return sock;
}

public I64 GopherDl
(U8* host, U16 port = 70, U8* selector, U8* query = NULL, U8* dest)
{
	CFile* f;
	U8 buf[BLK_SIZE];
	I64 data_len = 0, total_len = 0, got, sock;
	
	f = FOpen(dest, "w");
	if (!f)
	{
		PrintErr("Failed to open %s for writing\n", dest);
		return -1;
	}
	
	sock = GopherOpen(host, port, selector, query);
	if (sock < 0)
	{
		return sock;
	}
	
	while (TRUE)
	{
		got = recv(sock, buf + data_len, sizeof(buf) - data_len, 0);
		if (got <= 0)
		{
			if (data_len != 0 && !FBlkWrite(f, buf))
			{
				break;
			}
			f->de.size = total_len;
			FClose(f);
			return got;
		}
		data_len += got;
		total_len += got;
		if (data_len == BLK_SIZE)
		{
			if (!FBlkWrite(f, buf))
			{
				break;
			}
			data_len = 0;
		}
	}
	PrintErr("Write failed, %s may be corrupted\n", dest);
	FClose(f);
	return -1;
}

U0 PrintEscaped(U8* txt, U8* backslashes = "")
{
	U8* cur;
	U8 offending;
	
	while (cur = StrFirstOcc(txt, "$$\\\""))
	{
		offending = *cur;
		*cur = 0;
		if (offending == '$$')
		{
			"%s$$$$", txt;
		}
		else
		{
			"%s%s%c", txt, backslashes, offending;
		}
		txt = cur + 1;
	}
	"%s", txt;
}

U8* GopherBasename(U8* selector)
{
	U8* lastslash = StrLastOcc(selector, "/");
	if (lastslash == NULL)
	{
		return selector;
	}
	else
	{
		return lastslash + 1;
	}
}

U0 GopherTextView(U8* host, U16 port, U8* selector)
{
	U8* basename;
	U8* tmpname;
	
	DirMk("::/Tmp/Gopher");
	
	basename = ExtChg(GopherBasename(selector), "TXT");
	tmpname = StrPrint(NULL, "::/Tmp/Gopher/%s", basename);
	Free(basename);
	
	if (GopherDl(host, port, selector, , tmpname) == 0)
	{
		Plain(tmpname);
	}
	else
	{
		PrintErr("Failed to download %s from %s:%d\n",
			selector, host, port);
	}
	Free(tmpname);
}

U0 GopherLine(U8* line)
{
	U8 type;
	U8* display;
	U8* selector;
	U8* host = NULL;
	U16 port = 0;
	
	if (*line == 0)
	{
		"\n";
		return;
	}
	type = *line++;
	display = line;
	
	line = StrFind("\t", line);
	if (line)
	{
		*line = 0;
		line++;
	}	
	selector = line;

	if (line)
	{
		line = StrFind("\t", line);
	}
	if (line)
	{
		*line = 0;
		line++;
	}
	host = line;
	
	if (line)
	{
		line = StrFind("\t", line);
	}
	if (line)
	{
		*line = 0;
		line++;
		port = Str2I64(line);
	}
	
	switch (type)
	{
		case '3':
			PrintErr("");
		case 'i':
			PrintEscaped(display);
			break;
		default:
			"$$MA,\"";
			PrintEscaped(display, "\\");
			"\",LM=\"%s(\\\"", gopher_associations[type];
			PrintEscaped(host, "\\\\\\");
			"\\\",%d,\\\"", port;
			PrintEscaped(selector, "\\\\\\");
			"\\\");\\n\"$$";
	}
	"\n";
}

public I64 GopherMenu
(U8* host, U16 port = 70, U8* selector = "/", U8* query = NULL)
{
	I64 sock, n;
	U8 buf[256];
	
	sock = GopherOpen(host, port, selector, query);
	if (sock < 0)
	{
		return sock;
	}
	
	do 
	{
		n = recvLine(sock, buf, sizeof(buf), 0);
		if (StrCmp(buf, ".") == 0)
		{
			break;
		}
		GopherLine(buf);
	}
	while (n > 0);

	close(sock);
	return 0;
}

class CQueryForm
{
	U8 query[65] format "$$DA-P,A=\"Query:%s\"$$";
};
U0 GopherQueryPrompt(U8* host, U16 port, U8* selector)
{
	CQueryForm form;
	
	form.query[0] = 0;
	if (PopUpForm(&form))
	{
		GopherMenu(host, port, selector, form.query);
	}
}

class CDlForm
{
	U8 name[256] format "$$DA-P,LEN=255,A=\"FileName:%s\"$$";
};
U0 GopherDlPrompt(U8* host, U16 port, U8* selector)
{
	CDlForm form;
	U8* basename;
	
	basename = GopherBasename(selector);
	MemCpy(form.name, basename,
		MinI64(StrLen(basename), sizeof(form.name) - 1));
	form.name[255] = 0;
	if (PopUpForm(&form))
	{
		GopherDl(host, port, selector, , form.name);
	}
}

MemSetI64(gopher_associations, "GopherDlPrompt", 256);
gopher_associations['0'] = "GopherTextView";
gopher_associations['1'] = "GopherMenu";
gopher_associations['7'] = "GopherQueryPrompt";
/* Include this file from your HomeSys, then add more associations */

