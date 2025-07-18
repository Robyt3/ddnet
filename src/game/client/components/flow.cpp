/* (c) Magnus Auvinen. See licence.txt in the root of the distribution for more information. */
/* If you are missing that file, acquire a complete release at teeworlds.com.                */
#include "flow.h"
#include <engine/graphics.h>
#include <game/layers.h>
#include <game/mapitems.h>

CFlow::CFlow()
{
	m_pCells = nullptr;
	m_Height = 0;
	m_Width = 0;
	m_Spacing = 16;
}

void CFlow::DbgRender()
{
	if(!m_pCells)
		return;

	Graphics()->TextureClear();
	IGraphics::CLineItemBatch LineItemBatch;
	Graphics()->LinesBatchBegin(&LineItemBatch);
	for(int y = 0; y < m_Height; y++)
	{
		for(int x = 0; x < m_Width; x++)
		{
			vec2 Pos(x * m_Spacing, y * m_Spacing);
			vec2 Vel = m_pCells[y * m_Width + x].m_Vel * 0.01f;
			const IGraphics::CLineItem Item = IGraphics::CLineItem(Pos.x, Pos.y, Pos.x + Vel.x, Pos.y + Vel.y);
			Graphics()->LinesBatchDraw(&LineItemBatch, &Item, 1);
		}
	}
	Graphics()->LinesBatchEnd(&LineItemBatch);
}

void CFlow::Init()
{
	free(m_pCells);
	m_pCells = nullptr;

	CMapItemLayerTilemap *pTilemap = Layers()->GameLayer();
	m_Width = pTilemap->m_Width * 32 / m_Spacing;
	m_Height = pTilemap->m_Height * 32 / m_Spacing;

	// allocate and clear
	m_pCells = (CCell *)calloc((size_t)m_Width * m_Height, sizeof(CCell));
	for(int y = 0; y < m_Height; y++)
		for(int x = 0; x < m_Width; x++)
			m_pCells[y * m_Width + x].m_Vel = vec2(0.0f, 0.0f);
}

void CFlow::Update()
{
	if(!m_pCells)
		return;

	for(int y = 0; y < m_Height; y++)
		for(int x = 0; x < m_Width; x++)
			m_pCells[y * m_Width + x].m_Vel *= 0.85f;
}

vec2 CFlow::Get(vec2 Pos)
{
	if(!m_pCells)
		return vec2(0, 0);

	int x = (int)(Pos.x / m_Spacing);
	int y = (int)(Pos.y / m_Spacing);
	if(x < 0 || y < 0 || x >= m_Width || y >= m_Height)
		return vec2(0, 0);

	return m_pCells[y * m_Width + x].m_Vel;
}

void CFlow::Add(vec2 Pos, vec2 Vel, float Size)
{
	if(!m_pCells)
		return;

	int x = (int)(Pos.x / m_Spacing);
	int y = (int)(Pos.y / m_Spacing);
	if(x < 0 || y < 0 || x >= m_Width || y >= m_Height)
		return;

	m_pCells[y * m_Width + x].m_Vel += Vel;
}
